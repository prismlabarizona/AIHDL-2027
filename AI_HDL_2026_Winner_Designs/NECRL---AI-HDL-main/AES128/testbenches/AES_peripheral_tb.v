// AES Peripheral Integration Testbench
// Tests full encryption pipeline through the peripheral bus interface,
// including features: auto-start, key reuse, double-buffering

`timescale 1ns/1ps

module tb_tqvp_example;

    // -------------------------------------------------------------
    // Testbench Signals
    // -------------------------------------------------------------
    reg clk;
    reg rst_n;

    // TinyQV Bus Signals
    reg [7:0]   ui_in;
    wire [7:0]  uo_out;
    reg [5:0]   address;
    reg [31:0]  data_in;
    reg [1:0]   data_write_n; // 11=idle, 10=write 32-bit
    reg [1:0]   data_read_n;  // 11=idle, 10=read 32-bit
    wire [31:0] data_out;
    wire        data_ready;
    wire        user_interrupt;

    // Test Vectors (FIPS-197 Example)
    // Key:        2b7e1516 28aed2a6 abf71588 09cf4f3c
    // Plaintext:  3243f6a8 885a308d 313198a2 e0370734
    // Ciphertext: 3925841d 02dc09fb dc118597 196a0b32

    localparam [127:0] TEST_KEY   = 128'h2b7e151628aed2a6abf7158809cf4f3c;
    localparam [127:0] TEST_PLAIN = 128'h3243f6a8885a308d313198a2e0370734;
    localparam [127:0] EXPECTED   = 128'h3925841d02dc09fbdc118597196a0b32;

    reg [127:0] result_cipher;
    reg [31:0]  tmp;
    integer pass_count = 0;
    integer fail_count = 0;
    integer timeout_count;

    // -------------------------------------------------------------
    // Instantiate the DUT (Device Under Test)
    // -------------------------------------------------------------
    tqvp_necrl_spi dut (
        .clk(clk),
        .rst_n(rst_n),
        .ui_in(ui_in),
        .uo_out(uo_out),
        .address(address),
        .data_in(data_in),
        .data_write_n(data_write_n),
        .data_read_n(data_read_n),
        .data_out(data_out),
        .data_ready(data_ready),
        .user_interrupt(user_interrupt)
    );

    // -------------------------------------------------------------
    // Clock Generation (100MHz / 10ns)
    // -------------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;

    // -------------------------------------------------------------
    // Bus Helper Tasks
    // -------------------------------------------------------------

    // Task to WRITE to the peripheral
    task bus_write(input [5:0] addr, input [31:0] wdata);
        begin
            @(posedge clk);
            address      <= addr;
            data_in      <= wdata;
            data_write_n <= 2'b10; // 32-bit write active
            data_read_n  <= 2'b11; // Read idle

            @(posedge clk);
            data_write_n <= 2'b11; // Idle
            address      <= 6'h0;
            data_in      <= 32'h0;
        end
    endtask

    // Task to READ from the peripheral
    task bus_read(input [5:0] addr, output [31:0] rdata);
        begin
            @(posedge clk);
            address      <= addr;
            data_write_n <= 2'b11; // Write idle
            data_read_n  <= 2'b10; // 32-bit read active

            // Capture data_out BEFORE the next posedge to avoid the
            // streaming read_ptr NBA advancing and changing the output.
            #2; // wait for NBAs + combinational to settle
            rdata = data_out;

            @(posedge clk); // this edge increments read_ptr if streaming
            data_read_n  <= 2'b11; // Idle
            address      <= 6'h0;
        end
    endtask

    // Wait for interrupt with timeout
    // Handles sticky done: if done is already high (from prior encryption or
    // self-test), wait for it to clear first, then wait for the new assertion.
    task wait_for_done;
        begin
            timeout_count = 0;
            while (user_interrupt === 1'b1 && timeout_count < 500) begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
            end
            while (user_interrupt !== 1'b1 && timeout_count < 500) begin
                @(posedge clk);
                timeout_count = timeout_count + 1;
            end
            if (timeout_count >= 500) begin
                $display("  ERROR: Encryption timed out after 500 cycles!");
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Wait for Rank 8 boot self-test to complete and pass
    // It reads status register 0x01 repreatedlly and waits until:
    // tmp[2] == 1 -> selftest_done
    // tmp[3] == 0 -> selftest_fail == 0
    task wait_for_selftest_pass;
        begin
            timeout_count = 0;
            tmp = 32'h0;
            while (timeout_count < 800) begin
                bus_read(6'h01, tmp);
                if (tmp[2] === 1'b1) begin
                    if (tmp[3] === 1'b0) begin
                        $display("[INFO] Boot self-test completed and passed. status=0x%08h", tmp);
                        pass_count = pass_count + 1;
                    end else begin
                        $display("[ERROR] Boot self-test completed with failure. status=0x%08h", tmp);
                        fail_count = fail_count + 1;
                    end
                    timeout_count = 800;
                end else begin
                    @(posedge clk);
                    timeout_count = timeout_count + 1;
                end
            end
            if (tmp[2] !== 1'b1) begin
                $display("[ERROR] Boot self-test did not complete within timeout.");
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Check and report pass/fail
    task check_result(input [127:0] got, input [127:0] expected, input [8*40:1] label);
        begin
            if (got === expected) begin
                $display("  PASS %0s: 0x%032h", label, got);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL %0s: got 0x%032h expected 0x%032h", label, got, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Soft reset helper
    task do_soft_reset;
        begin
            bus_write(6'h00, 32'h00000002);
            repeat(3) @(posedge clk);
        end
    endtask

    // Read ciphertext via direct addresses 0x0A-0x0D into result_cipher
    task read_cipher_direct;
        begin
            bus_read(6'h0A, result_cipher[31:0]);
            bus_read(6'h0B, result_cipher[63:32]);
            bus_read(6'h0C, result_cipher[95:64]);
            bus_read(6'h0D, result_cipher[127:96]);
        end
    endtask

    // Load key via direct addresses
    task load_key;
        begin
            bus_write(6'h02, TEST_KEY[31:0]);
            bus_write(6'h03, TEST_KEY[63:32]);
            bus_write(6'h04, TEST_KEY[95:64]);
            bus_write(6'h05, TEST_KEY[127:96]);
        end
    endtask

    // Load plaintext via direct addresses
    task load_plain_direct;
        begin
            bus_write(6'h06, TEST_PLAIN[31:0]);
            bus_write(6'h07, TEST_PLAIN[63:32]);
            bus_write(6'h08, TEST_PLAIN[95:64]);
            bus_write(6'h09, TEST_PLAIN[127:96]);
        end
    endtask

    // -------------------------------------------------------------
    // Main Test Sequence
    // -------------------------------------------------------------
    initial begin
        // Initialize Signals
        rst_n = 0;
        ui_in = 8'h00;
        address = 0;
        data_in = 0;
        data_write_n = 2'b11;
        data_read_n = 2'b11;
        result_cipher = 128'b0;

        $display("\n=== AES Peripheral Integration Test Start ===");

        // Reset Sequence
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(2) @(posedge clk);
        $display("[INFO] Reset released.");

        // Rank 8: peripheral performs an automatic FIPS known-answer self-test at boot. Wait until it completes before issuing software-visible AES starts.
        wait_for_selftest_pass();

        // =========================================================
        // TEST 1: FIPS-197 — manual start, direct addresses
        // =========================================================
        $display("\n--- TEST 1: FIPS-197 (manual start, direct addresses) ---");

        load_key;
        load_plain_direct;

        $display("[INFO] Starting Encryption (manual start)...");
        bus_write(6'h00, 32'h00000001);

        wait_for_done;
        $display("[INFO] Encryption complete.");

        read_cipher_direct;
        check_result(result_cipher, EXPECTED, "FIPS-197_direct");

        do_soft_reset;

        // Rank 8 self-test status is sticky across soft reset.
        bus_read(6'h01, tmp);
        if (tmp[3:2] === 2'b01) begin
            $display("  PASS self-test status sticky across soft reset: 0x%08h", tmp);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL self-test status after soft reset: 0x%08h", tmp);
            fail_count = fail_count + 1;
        end

        // =========================================================
        // TEST 2: FIPS-197 — auto-start on direct address 0x09
        // =========================================================
        $display("\n--- TEST 2: FIPS-197 (auto-start via 0x09 write) ---");

        load_key;
        bus_write(6'h00, 32'h00000008); // auto_start = 1

        // Write plaintext — writing to 0x09 should auto-trigger
        load_plain_direct; // last write is 0x09 → auto-start

        wait_for_done;
        $display("[INFO] Encryption complete (auto-start).");

        read_cipher_direct;
        check_result(result_cipher, EXPECTED, "FIPS-197_auto_start");

        do_soft_reset;

        // =========================================================
        // TEST 3: Key reuse — encrypt same block twice, same result
        // =========================================================
        $display("\n--- TEST 3: Key reuse (encrypt twice, same result) ---");

        load_key;
        bus_write(6'h00, 32'h0000000C); // key_lock + auto_start

        // First encryption via direct addresses
        load_plain_direct;
        wait_for_done;
        $display("[INFO] First encryption done.");
        read_cipher_direct;
        check_result(result_cipher, EXPECTED, "key_reuse_enc1");

        // Second encryption — no key rewrite needed
        load_plain_direct;
        wait_for_done;
        $display("[INFO] Second encryption done (key reused).");
        read_cipher_direct;
        check_result(result_cipher, EXPECTED, "key_reuse_enc2");

        do_soft_reset;

        // =========================================================
        // TEST 4: Double-buffering — write next block while encrypting
        // =========================================================
        $display("\n--- TEST 4: Double-buffering (overlap writes with encryption) ---");

        load_key;
        bus_write(6'h00, 32'h0000000C); // key_lock + auto_start

        // Block 1: write plaintext via direct addresses, auto-starts on 0x09
        $display("[INFO] Block 1: writing plaintext...");
        load_plain_direct;
        // Engine now encrypting Block 1; CPU can write to idle bank
        $display("[INFO] Block 1 encrypting. Writing Block 2 to idle bank...");
        // Write first 3 words of Block 2 while Block 1 encrypts
        bus_write(6'h06, TEST_PLAIN[31:0]);
        bus_write(6'h07, TEST_PLAIN[63:32]);
        bus_write(6'h08, TEST_PLAIN[95:64]);

        // Wait for Block 1 to finish
        wait_for_done;
        $display("[INFO] Block 1 complete.");
        read_cipher_direct;
        check_result(result_cipher, EXPECTED, "dblbuf_block1");

        // Write 4th word of Block 2 → auto-starts Block 2
        bus_write(6'h09, TEST_PLAIN[127:96]);

        wait_for_done;
        $display("[INFO] Block 2 complete.");
        read_cipher_direct;
        check_result(result_cipher, EXPECTED, "dblbuf_block2");

        do_soft_reset;

        // =========================================================
        // TEST 7: Soft Reset clears state
        // =========================================================
        $display("\n--- TEST 7: Soft Reset clears state ---");

        load_key;
        // Wait a cycle so the NBA from the final bus_write (to 0x05) commits
        // into key_mem[3] before we sample original_key.
        @(posedge clk); #1;
        // Key registers are write-only on the bus (Rank 1 fix): bus reads of
        // 0x02-0x05 always return 0. Verify the key actually landed in the
        // internal register by peeking at original_key (key_mem[3:0] concat).
        if (dut.aes_memory_inst.original_key === TEST_KEY) begin
            $display("  PASS key written before reset");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL key written before reset: got 0x%032h", dut.aes_memory_inst.original_key);
            fail_count = fail_count + 1;
        end

        do_soft_reset;

        // After soft reset the internal key register itself must be zero —
        // bus readback is 0 unconditionally now, so that's not honest evidence.
        if (dut.aes_memory_inst.original_key === 128'h0) begin
            $display("  PASS key cleared after reset");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL key not cleared: 0x%032h", dut.aes_memory_inst.original_key);
            fail_count = fail_count + 1;
        end

        bus_read(6'h00, tmp);
        if (tmp === 32'h0) begin
            $display("  PASS control reg cleared after reset");
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL control reg not cleared: 0x%08h", tmp);
            fail_count = fail_count + 1;
        end

        // =========================================================
        // SUMMARY
        // =========================================================
        $display("\n=============================");
        $display("  PASSED: %0d", pass_count);
        $display("  FAILED: %0d", fail_count);
        if (fail_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  SOME TESTS FAILED");
        $display("=============================\n");

        #10;
        $finish;
    end

    // Waveform Dump
    initial begin
        $dumpfile("aes_test.vcd");
        $dumpvars(0, tb_tqvp_example);
    end

endmodule
