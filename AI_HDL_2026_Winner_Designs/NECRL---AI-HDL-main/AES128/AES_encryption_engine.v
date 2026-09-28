module AES_encryption_engine (
    input               clk,
    input               reset,
    input               stall,
    input       [4:0]   count,
    input       [127:0] encryption_engine_data,
    input       [127:0] round_key,
    output      [127:0] cipher
);

  reg  [127:0] state_reg;
  reg  [63:0]  sub_out_hi;  // stores upper 8 SubBytes results from phase A
  reg  [127:0] sr_reg;      // pipelined ShiftRows output (Phase B1 → B2)

  // cipher output is just state_reg — memory latches it on 'done'
  assign cipher = state_reg;

  wire [63:0]  sbox_out;    // 8 S-box outputs
  wire [127:0] sub_out;     // full 16-byte SubBytes result (combined)
  wire [127:0] mc_out;
  wire [127:0] sr_out;

  // Phase decoding (count 1..31 scheme; count=1 = init; 3-cycle main rounds A/B1/B2;
  //                 final = A,B in 2 cycles; count=31 = done transition)
  // count=1:        init — AddRoundKey only
  // counts 2..28:   rounds 1..9 (A,B1,B2) — count-2 ≡ 0/1/2 (mod 3) → A/B1/B2
  // counts 29,30:   final round (A, B no-MC)
  wire is_init    = (count == 5'd1);   // init AddRoundKey only
  wire is_final_a = (count == 5'd29);
  wire is_final_b = (count == 5'd30);

  // Main rounds 1..9: A at counts 2,5,8,...,26; B1 at 3,6,...,27; B2 at 4,7,...,28.
  wire phase_a  = (count == 5'd2  || count == 5'd5  || count == 5'd8  ||
                   count == 5'd11 || count == 5'd14 || count == 5'd17 ||
                   count == 5'd20 || count == 5'd23 || count == 5'd26);

  wire phase_b1 = (count == 5'd3  || count == 5'd6  || count == 5'd9  ||
                   count == 5'd12 || count == 5'd15 || count == 5'd18 ||
                   count == 5'd21 || count == 5'd24 || count == 5'd27);

  wire phase_b2 = (count == 5'd4  || count == 5'd7  || count == 5'd10 ||
                   count == 5'd13 || count == 5'd16 || count == 5'd19 ||
                   count == 5'd22 || count == 5'd25 || count == 5'd28);

  wire is_final = is_final_a || is_final_b;

  // init_state computed for the init cycle (count=1); sbox operates on state_reg otherwise.
  wire [127:0] init_state         = encryption_engine_data ^ round_key;
  wire [63:0]  state_for_sbox_hi  = state_reg[127:64];
  wire [63:0]  state_for_sbox_lo  = state_reg[63:0];

  // Final round B also needs the lower-half sbox (same 2-cycle A/B structure as old scheme).
  wire sbox_active = phase_a || is_final_a || phase_b1 || is_final_b;
  wire [63:0] sbox_in = sbox_active
                      ? ((phase_a || is_final_a) ? state_for_sbox_hi : state_for_sbox_lo)
                      : 64'b0;

  // 8 S-box instances (reduced from 16)
  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : make_sboxes
      sbox_lookup sbox_inst (
        .addr(sbox_in[63 - i*8 -: 8]),
        .out (sbox_out[63 - i*8 -: 8])
      );
    end
  endgenerate

  // Combine phase A (registered) and phase B (live) into full 128-bit sub_out
  assign sub_out = {sub_out_hi, sbox_out};

  assign sr_out[127:120] = sub_out[127:120];
  assign sr_out[95:88]   = sub_out[95:88];
  assign sr_out[63:56]   = sub_out[63:56];
  assign sr_out[31:24]   = sub_out[31:24];

  assign sr_out[119:112] = sub_out[87:80];
  assign sr_out[87:80]   = sub_out[55:48];
  assign sr_out[55:48]   = sub_out[23:16];
  assign sr_out[23:16]   = sub_out[119:112];

  assign sr_out[111:104] = sub_out[47:40];
  assign sr_out[79:72]   = sub_out[15:8];
  assign sr_out[47:40]   = sub_out[111:104];
  assign sr_out[15:8]    = sub_out[79:72];

  assign sr_out[103:96]  = sub_out[7:0];
  assign sr_out[71:64]   = sub_out[103:96];
  assign sr_out[39:32]   = sub_out[71:64];
  assign sr_out[7:0]     = sub_out[39:32];

  // MixColumns operand isolation: only active during non-final rounds in phase B
  wire mc_active = phase_b2;  // MixColumns operand only valid in B2 (uses sr_reg)
  wire [127:0] mc_operand = mc_active ? sr_reg : 128'b0;

  mix_columns u_mix_columns (
    .data_in(mc_operand),
    .data_out(mc_out)
  );

  always @(posedge clk or posedge reset) begin
    if (reset) begin
      state_reg   <= 128'b0;
      sub_out_hi  <= 64'b0;
      sr_reg      <= 128'b0;
    end else if (!stall) begin
      if (count == 5'd0) begin
        // idle - hold
      end else if (is_init) begin
        // Init: AddRoundKey with round_key_0 (original key)
        state_reg <= init_state;
      end else if (phase_a || is_final_a) begin
        // Phase A (rounds 1..9 or final): register upper 8 SubBytes results
        sub_out_hi <= sbox_out;
      end else if (phase_b1) begin
        // Phase B1: capture ShiftRows output for next cycle's MixColumns
        sr_reg <= sr_out;
      end else if (phase_b2) begin
        // Phase B2: MixColumns on registered sr_reg, then ⊕key, then writeback (short path)
        state_reg <= mc_out ^ round_key;
      end else if (is_final_b) begin
        // Final round B: ShiftRows + AddRoundKey (no MixColumns, no pipeline split)
        state_reg <= sr_out ^ round_key;
      end
    end
  end

endmodule
