/*
 * Copyright (c) 2025 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Change the name of this module to something that reflects its functionality and includes your name for uniqueness
// For example tqvp_yourname_spi for an SPI peripheral.
// Then edit tt_wrapper.v line 41 and change tqvp_example to your chosen module name.
module tqvp_necrl_spi (
    input         clk,          // Clock - the TinyQV project clock is normally set to 64MHz.
    input         rst_n,        // Reset_n - low to reset.

    input  [7:0]  ui_in,        // The input PMOD, always available.  Note that ui_in[7] is normally used for UART RX.
                                // The inputs are synchronized to the clock, note this will introduce 2 cycles of delay on the inputs.

    output [7:0]  uo_out,       // The output PMOD.  Each wire is only connected if this peripheral is selected.
                                // Note that uo_out[0] is normally used for UART TX.

    input [5:0]   address,      // Address within this peripheral's address space
    input [31:0]  data_in,      // Data in to the peripheral, bottom 8, 16 or all 32 bits are valid on write.

    // Data read and write requests from the TinyQV core.
    input [1:0]   data_write_n, // 11 = no write, 00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    input [1:0]   data_read_n,  // 11 = no read,  00 = 8-bits, 01 = 16-bits, 10 = 32-bits
    
    output [31:0] data_out,     // Data out from the peripheral, bottom 8, 16 or all 32 bits are valid on read when data_ready is high.
    output        data_ready,

    output        user_interrupt  // Dedicated interrupt request for this peripheral
);

    // -------------------------------------------------------------
    // Internal Wires for Module Interconnections
    // -------------------------------------------------------------
    wire start;
    wire done;
    wire [127:0] encryption_engine_data;
    wire [127:0] original_key;
    wire [127:0] ciphertext;
    wire [127:0] round_key;
    wire [4:0]   encryption_engine_count;
    wire key_engine_start;
    wire reset_s;       // Soft reset from memory
    wire core_reset;    // Combined reset (System OR Soft)
    wire fault;         // Rank 2: control unit detected FSM/counter integrity failure
    wire stall;         // Rank 6: LFSR-based random stall for DPA countermeasure
    // Engines see reset OR fault so a detected fault wipes state_reg,
    // sub_out_hi, and round_key via their existing async-reset paths.
    wire engine_reset = core_reset | fault;

    //Rank 8: power-on known-answer self-test status
    reg  selftest_active;
    reg  selftest_started;
    reg  selftest_start;
    reg  selftest_done;
    reg  selftest_fail;
    reg  selftest_clear;
    reg  done_d;

    // Standard FIPS 197 AES-128 known-answer test vector
    localparam [127:0] SELFTEST_KEY        = 128'h00010203_04050607_08090A0B_0C0D0E0F;
    localparam [127:0] SELFTEST_PLAINTEXT  = 128'h00112233_44556677_8899AABB_CCDDEEFF;
    localparam [127:0] SELFTEST_CIPHERTEXT = 128'h69C4E0D8_6A7B0430_D8CDB780_70B4C55A;

    wire [127:0] selected_key  = selftest_active ? SELFTEST_KEY       : original_key;
    wire [127:0] selected_data = selftest_active ? SELFTEST_PLAINTEXT : encryption_engine_data;

    wire effective_start;
    assign effective_start = selftest_active ? selftest_start
                                             : (selftest_done && !selftest_fail && start);

    // -------------------------------------------------------------
    // Rank 8: Power-on self-test controller
    // -------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            selftest_active  <= 1'b1;
            selftest_started <= 1'b0;
            selftest_start   <= 1'b0;
            selftest_done    <= 1'b0;
            selftest_fail    <= 1'b0;
            selftest_clear   <= 1'b0;
            done_d           <= 1'b0;
        end else begin
            selftest_start <= 1'b0;
            selftest_clear <= 1'b0;
            done_d         <= done;

            if (selftest_active) begin
                if (!selftest_started) begin
                    selftest_started <= 1'b1;
                    selftest_start   <= 1'b1;
                end else if (done) begin
                    selftest_done   <= 1'b1;
                    selftest_fail   <= (ciphertext != SELFTEST_CIPHERTEXT);
                    selftest_active <= 1'b0;
                    selftest_clear  <= 1'b1;
                end
            end
        end
    end

    // -------------------------------------------------------------
    // AES Memory
    // -------------------------------------------------------------
    AES_memory aes_memory_inst (
        .clk(clk),
        .address(address),
        .data_in(data_in),
        .data_out(data_out),
        .data_write_n(data_write_n),
        .data_read_n(data_read_n),
        .ciphertext(ciphertext),

        .start(start),
        .done(done),
        .fault(fault),
        .selftest_done(selftest_done),
        .selftest_fail(selftest_fail),
        .encryption_engine_data(encryption_engine_data),
        .original_key(original_key),
        .reset_s(reset_s)
    );

    // -------------------------------------------------------------
    // AES Control unit
    // -------------------------------------------------------------
    AES_control_unit aes_control_unit_inst (
        .clk(clk),
        .start(effective_start),
        .reset_n(~rst_n), //Invert system active-low reset to active-high
        .reset_s(reset_s | selftest_clear),

        .done(done),
        .encryption_engine_count(encryption_engine_count),
        .key_engine_start(key_engine_start),
        .reset(core_reset),
        .fault(fault),
        .stall(stall)
    );

    // -------------------------------------------------------------
    // AES Encryption Engine
    // -------------------------------------------------------------
    AES_encryption_engine aes_encryption_engine_inst (
        .clk(clk),
        .reset(engine_reset),
        .stall(stall),
        .count(encryption_engine_count),
        .encryption_engine_data(selected_data),
        .round_key(round_key),

        .cipher(ciphertext)
    );

    // -------------------------------------------------------------
    // AES Key Engine
    // -------------------------------------------------------------
    AES_key_engine aes_key_engine_inst (
        .clk(clk),
        .reset(engine_reset),
        .stall(stall),
        .count(encryption_engine_count),
        .key_engine_start(key_engine_start),
        .original_key(selected_key),

        .round_key(round_key)
    );

    // -------------------------------------------------------------
    // System Outputs
    // -------------------------------------------------------------
    
    // Reads are combinational in AES_memory, so data is ready immediately
    assign data_ready = 1'b1;

    // Fire interrupt when encryption is done
    assign user_interrupt = done;

    // Unused outputs
    assign uo_out = 8'b0; 

    // Unused inputs (prevent warnings)
    wire _unused = &{ui_in, 1'b0};

endmodule
