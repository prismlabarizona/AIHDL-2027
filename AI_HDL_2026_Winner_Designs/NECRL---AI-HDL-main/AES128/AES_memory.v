module AES_memory (
    input clk,
    input [1:0] data_read_n,
    input [1:0] data_write_n,
    input [31:0] data_in,
    input [5:0] address,
    input [127:0] ciphertext,
    input done,
    input fault,
    input selftest_done, //Added visibility - Rank 8
    input selftest_fail, //Added visibility - Rank 8 
    output reg [31:0] data_out,
    output start,
    output [127:0] encryption_engine_data,
    output [127:0] original_key,
    output reg reset_s
);

    // control register bits:
    // bit0: start          — triggers encryption (auto-cleared when done)
    // bit1: reset (soft)   — clears all memories and resets engine
    // bit2: key_lock       — prevents accidental key overwrites
    // bit3: auto_start     — when set, writing last plaintext word auto-triggers encryption
    //
    // status register bits (addr 0x01):
    // bit0: done           — encryption complete - Rank 8
    // bit1: fault          — FSM / counter integrity failure detected - Rank 8
    // bit2: selftest_done  — power-on FIPS known-answer test finished - Rank 8
    // bit3: selftest_fail  — power-on FIPS known-answer test failed - Rank 8
    //
    // Key reuse: key_mem persists across encryptions. Write the key once,
    // set key_lock, then encrypt unlimited blocks without rewriting the key.
    // The key engine re-derives round keys in parallel with encryption
    // (zero extra latency). Clear the key with a soft reset (bit1) when done.
    //
    // Double-buffering (ping-pong):
    //   Two plaintext input banks (A and B). The CPU always writes to the
    //   idle bank selected by 'active_bank'. When encryption starts, banks
    //   swap: the engine reads from the just-filled bank while the CPU can
    //   immediately write the next block into the other bank. This lets the
    //   CPU overlap ciphertext reads + next plaintext writes with encryption.

    // initialize control_reg to avoid X propagation on power-up
    reg [31:0] control_reg = 32'b0;

    // memories: 4 x 32-bit words for key, data_out
    reg [31:0] key_mem [0:3];
    reg [31:0] data_out_mem [0:3];

    // double-buffered plaintext input (ping-pong banks A and B)
    reg [31:0] data_in_bank_a [0:3];
    reg [31:0] data_in_bank_b [0:3];
    reg        active_bank = 1'b0;  // 0 = engine reads A, CPU writes B
                                    // 1 = engine reads B, CPU writes A

    // status is driven from 'done' input
    wire status_done = done;

    // start is bit0 of control register
    assign start = control_reg[0];

    // encryption_engine_data reads from the ACTIVE bank (the one just filled)
    assign encryption_engine_data = active_bank ?
        {data_in_bank_b[3], data_in_bank_b[2], data_in_bank_b[1], data_in_bank_b[0]} :
        {data_in_bank_a[3], data_in_bank_a[2], data_in_bank_a[1], data_in_bank_a[0]};

    //original key is concatenation of key_mem[3:0] (msb..lsb)
    assign original_key = {key_mem[3], key_mem[2], key_mem[1], key_mem[0]};

    // synchronous logic: writes and latch-on-done. Reset is performed by
    // writing bit1 in the control register (control reg at addr 0x00).
    always @(posedge clk) begin
        reset_s <= 1'b0;

        // Auto-clear start bit when engine signals done;
        // write_ptr already reset by bank swap at start time.
        if (status_done) begin
            control_reg[0] <= 1'b0;
            data_out_mem[0] <= ciphertext[31:0];
            data_out_mem[1] <= ciphertext[63:32];
            data_out_mem[2] <= ciphertext[95:64];
            data_out_mem[3] <= ciphertext[127:96];
        end

        // accept only 32-bit writes (TinyQV encoding: 00=8-bit, 01=16-bit, 10=32-bit, 11=no write)
        if (data_write_n == 2'b10) begin
            case (address)
                6'h00: begin
                    // Rank 5 interlock: while the engine is busy
                    // (control_reg[0] == 1), suppress CPU control-reg writes
                    // that would disturb an in-flight encryption.
                    //   - bit1 (soft reset): dropped — prevents DoS wipes and
                    //     mid-expansion key corruption (leaks original key).
                    //   - bit0 (start): preserved — a CPU write of 0 must not
                    //     silently de-assert start mid-run; start is cleared
                    //     only by `done`.
                    // Other bits (key_lock, auto_start) are safe to update.
                    if (control_reg[0]) begin
                        control_reg <= {data_in[31:2], 1'b0, control_reg[0]};
                    end else begin
                        control_reg <= data_in;
                        // if start bit set: swap banks
                        if (data_in[0]) begin
                            active_bank <= ~active_bank; // swap: CPU's write bank becomes engine's read bank
                        end
                    end
                    // Soft reset is only honored when the engine is idle.
                    if (data_in[1] && !control_reg[0]) begin
                        reset_s <= 1'b1;
                        control_reg <= 32'b0;
                        key_mem[0] <= 32'b0;
                        key_mem[1] <= 32'b0;
                        key_mem[2] <= 32'b0;
                        key_mem[3] <= 32'b0;
                        data_in_bank_a[0] <= 32'b0;
                        data_in_bank_a[1] <= 32'b0;
                        data_in_bank_a[2] <= 32'b0;
                        data_in_bank_a[3] <= 32'b0;
                        data_in_bank_b[0] <= 32'b0;
                        data_in_bank_b[1] <= 32'b0;
                        data_in_bank_b[2] <= 32'b0;
                        data_in_bank_b[3] <= 32'b0;
                        data_out_mem[0] <= 32'b0;
                        data_out_mem[1] <= 32'b0;
                        data_out_mem[2] <= 32'b0;
                        data_out_mem[3] <= 32'b0;
                        active_bank <= 1'b0;
                    end
                end

                // Keys: 0x02 - 0x05 (only writable if key_lock == 0)
                6'h02, 6'h03, 6'h04, 6'h05: begin
                    if (!control_reg[2]) begin // key_lock == 0 allows writes
                        key_mem[address - 6'h02] <= data_in;
                    end
                end

                // Data in: direct-addressed at 0x06 - 0x09
                // Writes go to the IDLE bank (opposite of active_bank)
                6'h06, 6'h07, 6'h08, 6'h09: begin
                    if (active_bank)
                        data_in_bank_a[address - 6'h06] <= data_in;
                    else
                        data_in_bank_b[address - 6'h06] <= data_in;
                    // Auto-start: if bit3 set and this is the last word (0x09)
                    if (control_reg[3] && address == 6'h09) begin
                        control_reg[0] <= 1'b1;   // assert start
                        active_bank <= ~active_bank; // swap banks
                    end
                end

                // ignore writes to data_out range and other addresses (read-only)
                default: begin
                    // no action
                end
            endcase
        end

    end

    // read logic (combinational)
    always @(*) begin
        // accept only 32-bit reads (TinyQV encoding: 00=8-bit, 01=16-bit, 10=32-bit, 11=no read)
        if (data_read_n == 2'b10) begin
            case (address)
                6'h00: data_out = control_reg;
                // status reg: bit0 = done, bit1 = fault (Rank 7).
                // Software polls bit0 for completion and bit1 to distinguish
                // "still running" from "halted by FSM/counter integrity
                // failure" (see AES_control_unit FAULT state).
                6'h01: data_out = {28'b0, selftest_fail, selftest_done, fault, status_done}; //Added selftest_fail and selftest_done. Changed 30'b0 to 28'b0. - Rank 8
                // At address 0x01 software now sees: (Rank 8)
                // [3] selftest_fail
                // [2] selftest_done
                // [1] fault
                // [0] done
                //
                // Key registers are write-only. Reads return zero so that a
                // compromised or buggy bus master cannot exfiltrate the secret
                // key. key_lock (control_reg[2]) prevents *overwrites*; this
                // clause prevents *reads*. Both are required — see security
                // report Rank 1 (DP3_submission/security_report.pdf).
                6'h02: data_out = 32'b0;
                6'h03: data_out = 32'b0;
                6'h04: data_out = 32'b0;
                6'h05: data_out = 32'b0;

                // Data in: 0x06 - 0x09 (reads from the IDLE bank, same one CPU writes to)
                6'h06: data_out = active_bank ? data_in_bank_a[0] : data_in_bank_b[0];
                6'h07: data_out = active_bank ? data_in_bank_a[1] : data_in_bank_b[1];
                6'h08: data_out = active_bank ? data_in_bank_a[2] : data_in_bank_b[2];
                6'h09: data_out = active_bank ? data_in_bank_a[3] : data_in_bank_b[3];

                // Data out: direct-addressed at 0x0A - 0x0D
                6'h0A: data_out = data_out_mem[0];
                6'h0B: data_out = data_out_mem[1];
                6'h0C: data_out = data_out_mem[2];
                6'h0D: data_out = data_out_mem[3];

                default: data_out = 32'b0;
            endcase
        end else begin
            data_out = 32'b0;
        end
    end

endmodule
