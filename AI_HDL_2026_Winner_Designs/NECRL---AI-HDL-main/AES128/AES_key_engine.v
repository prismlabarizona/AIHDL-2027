module AES_key_engine (
    input clk,
    input reset,
    input stall,
    input       [4:0]   count,           // encryption count; used to pace key expansion
    input key_engine_start,
    input [127:0] original_key,
    output reg [127:0] round_key
);

    reg [127:0] temp_key;
    wire [127:0] next_key;

    reg [3:0] current_state;
    reg [3:0] next_state;    // driven by combinational block
    reg       key_phase;     // 0 = phase A (upper 2 bytes), 1 = phase B (lower 2 bytes)
    reg [15:0] sub_word_hi;  // stores upper 2 SubWord bytes from phase A

    wire [31:0] rotated_word;
    wire [31:0] substituted_word;
    wire [31:0] word_0, word_1, word_2, word_3;

    localparam [3:0] PREP = 4'b0000;

    // S-box operand: 2 bytes at a time, selected by key_phase
    wire key_sbox_active = (current_state != PREP);
    wire [15:0] key_sbox_in = key_sbox_active ?
        (key_phase ? rotated_word[15:0] : rotated_word[31:16]) : 16'b0;
    wire [15:0] key_sbox_out;

    // 2 S-box instances (reduced from 4)
    sbox_lookup sbox0 (
        .addr(key_sbox_in[15:8]),
        .out (key_sbox_out[15:8])
    );
    sbox_lookup sbox1 (
        .addr(key_sbox_in[7:0]),
        .out (key_sbox_out[7:0])
    );

    // Combine phase A (registered) and phase B (live) into full substituted_word
    assign substituted_word = {sub_word_hi, key_sbox_out};

    localparam [3:0] 
        R0        = 4'b0001,
        R1        = 4'b0010,
        R2        = 4'b0011,
        R3        = 4'b0100,
        R4        = 4'b0101,
        R5        = 4'b0110,
        R6        = 4'b0111,
        R7        = 4'b1000,
        R8        = 4'b1001,
        R9        = 4'b1010,
        R10       = 4'b1011;

        
    function [31:0] get_rcon;
    input [3:0] round;
    begin
        case (round)
            4'd0: get_rcon = 32'h01000000;
            4'd1: get_rcon = 32'h02000000;
            4'd2: get_rcon = 32'h04000000;
            4'd3: get_rcon = 32'h08000000;
            4'd4: get_rcon = 32'h10000000;
            4'd5: get_rcon = 32'h20000000;
            4'd6: get_rcon = 32'h40000000;
            4'd7: get_rcon = 32'h80000000;
            4'd8: get_rcon = 32'h1b000000;
            4'd9: get_rcon = 32'h36000000;
            default: get_rcon = 32'h00000000;
        endcase
    end
    endfunction

    assign rotated_word = {temp_key[23:0], temp_key[31:24]};
    assign word_0  = temp_key[127:96] ^ (substituted_word ^ get_rcon(current_state-1));
    assign word_1  = temp_key[95:64]  ^ word_0;
    assign word_2  = temp_key[63:32]  ^ word_1;
    assign word_3  = temp_key[31:0]   ^ word_2;

    assign next_key = {word_0, word_1, word_2, word_3};

    // Combinational next-state logic
    always @(*) begin
        next_state = PREP;
        case(current_state)
            PREP: begin
                if (key_engine_start == 1'b1)
                    next_state = R0;
                else
                    next_state = PREP;
            end
            R0:  next_state = R1;
            R1:  next_state = R2;
            R2:  next_state = R3;
            R3:  next_state = R4;
            R4:  next_state = R5;
            R5:  next_state = R6;
            R6:  next_state = R7;
            R7:  next_state = R8;
            R8:  next_state = R9;
            R9:  next_state = R10;
            R10: next_state = PREP;
            default: next_state = PREP;
        endcase
    end

    // Pace key expansion to match 3-cycle encryption rounds (A, B1, B2).
    // Hold during B1 cycles (count 3,6,9,...,27) so the key engine's phB
    // executes during B2, making next_key (the fresh round key) valid at
    // exactly the same cycle the encryption engine's phase_b2 fires.
    // key_hold counts == phase_b1 counts in the encryption engine; explicit list
    // (consistent with phase decoding style in AES_encryption_engine.v).
    wire key_hold = (count == 5'd3  || count == 5'd6  || count == 5'd9  ||
                     count == 5'd12 || count == 5'd15 || count == 5'd18 ||
                     count == 5'd21 || count == 5'd24 || count == 5'd27);

    // Sequential logic with 2-phase key expansion
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            current_state <= PREP;
            temp_key      <= 128'b0;
            key_phase     <= 1'b0;
            sub_word_hi   <= 16'b0;
        end else if (!stall && !key_hold) begin
            if (current_state == PREP) begin
                temp_key  <= original_key;
                key_phase <= 1'b0;
                if (key_engine_start)
                    current_state <= R0;
            end else if (!key_phase) begin
                // Phase A: register upper 2 SubWord bytes, advance to phase B
                sub_word_hi <= key_sbox_out;
                key_phase   <= 1'b1;
            end else begin
                // Phase B: compute next_key, advance state, reset phase
                temp_key      <= next_key;
                key_phase     <= 1'b0;
                current_state <= next_state;
            end
        end
    end

    // Output mux.
    // During phB (key_phase==1), output next_key directly so the freshly-computed
    // round key is visible to the encryption engine in the same cycle (phase_b2)
    // without waiting for the NBA to commit temp_key.  During phA (key_phase==0)
    // the encryption engine does not need round_key, so temp_key is fine.
    always @(*) begin
        if (current_state == PREP)
            round_key = original_key;
        else if (key_phase == 1'b1)
            round_key = next_key;    // phB: output the key being written this cycle
        else
            round_key = temp_key;    // phA: output previous round's key (unused by engine)
    end

endmodule


