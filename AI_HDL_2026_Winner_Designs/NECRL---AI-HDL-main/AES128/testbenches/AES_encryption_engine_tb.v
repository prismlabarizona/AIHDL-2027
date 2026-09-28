`timescale 1ns/1ps

module tb_AES_encryption_engine;

  reg               clk;
  reg               reset;
  reg   [4:0]       count;
  reg   [127:0]     encryption_engine_data;
  reg   [127:0]     round_key;
  wire  [127:0]     cipher;

  AES_encryption_engine dut (
    .clk(clk),
    .reset(reset),
    .stall(1'b0),
    .count(count),
    .encryption_engine_data(encryption_engine_data),
    .round_key(round_key),
    .cipher(cipher)
  );

  // --- Helper Functions ---

  function automatic [7:0] mulTwo(input [7:0] byte_in);
    if (byte_in[7])
      mulTwo = (byte_in << 1) ^ 8'h1b;
    else
      mulTwo = (byte_in << 1);
  endfunction

  function automatic [7:0] mulThree(input [7:0] byte_in);
    mulThree = mulTwo(byte_in) ^ byte_in;
  endfunction

  // REAL AES S-BOX LOOKUP
  function automatic [7:0] get_sbox_val(input [7:0] addr);
    case (addr)
        8'h00: get_sbox_val = 8'h63; 8'h01: get_sbox_val = 8'h7c; 8'h02: get_sbox_val = 8'h77; 8'h03: get_sbox_val = 8'h7b;
        8'h04: get_sbox_val = 8'hf2; 8'h05: get_sbox_val = 8'h6b; 8'h06: get_sbox_val = 8'h6f; 8'h07: get_sbox_val = 8'hc5;
        8'h08: get_sbox_val = 8'h30; 8'h09: get_sbox_val = 8'h01; 8'h0a: get_sbox_val = 8'h67; 8'h0b: get_sbox_val = 8'h2b;
        8'h0c: get_sbox_val = 8'hfe; 8'h0d: get_sbox_val = 8'hd7; 8'h0e: get_sbox_val = 8'hab; 8'h0f: get_sbox_val = 8'h76;
        8'h10: get_sbox_val = 8'hca; 8'h11: get_sbox_val = 8'h82; 8'h12: get_sbox_val = 8'hc9; 8'h13: get_sbox_val = 8'h7d;
        8'h14: get_sbox_val = 8'hfa; 8'h15: get_sbox_val = 8'h59; 8'h16: get_sbox_val = 8'h47; 8'h17: get_sbox_val = 8'hf0;
        8'h18: get_sbox_val = 8'had; 8'h19: get_sbox_val = 8'hd4; 8'h1a: get_sbox_val = 8'ha2; 8'h1b: get_sbox_val = 8'haf;
        8'h1c: get_sbox_val = 8'h9c; 8'h1d: get_sbox_val = 8'ha4; 8'h1e: get_sbox_val = 8'h72; 8'h1f: get_sbox_val = 8'hc0;
        8'h20: get_sbox_val = 8'hb7; 8'h21: get_sbox_val = 8'hfd; 8'h22: get_sbox_val = 8'h93; 8'h23: get_sbox_val = 8'h26;
        8'h24: get_sbox_val = 8'h36; 8'h25: get_sbox_val = 8'h3f; 8'h26: get_sbox_val = 8'hf7; 8'h27: get_sbox_val = 8'hcc;
        8'h28: get_sbox_val = 8'h34; 8'h29: get_sbox_val = 8'ha5; 8'h2a: get_sbox_val = 8'he5; 8'h2b: get_sbox_val = 8'hf1;
        8'h2c: get_sbox_val = 8'h71; 8'h2d: get_sbox_val = 8'hd8; 8'h2e: get_sbox_val = 8'h31; 8'h2f: get_sbox_val = 8'h15;
        8'h30: get_sbox_val = 8'h04; 8'h31: get_sbox_val = 8'hc7; 8'h32: get_sbox_val = 8'h23; 8'h33: get_sbox_val = 8'hc3;
        8'h34: get_sbox_val = 8'h18; 8'h35: get_sbox_val = 8'h96; 8'h36: get_sbox_val = 8'h05; 8'h37: get_sbox_val = 8'h9a;
        8'h38: get_sbox_val = 8'h07; 8'h39: get_sbox_val = 8'h12; 8'h3a: get_sbox_val = 8'h80; 8'h3b: get_sbox_val = 8'he2;
        8'h3c: get_sbox_val = 8'heb; 8'h3d: get_sbox_val = 8'h27; 8'h3e: get_sbox_val = 8'hb2; 8'h3f: get_sbox_val = 8'h75;
        8'h40: get_sbox_val = 8'h09; 8'h41: get_sbox_val = 8'h83; 8'h42: get_sbox_val = 8'h2c; 8'h43: get_sbox_val = 8'h1a;
        8'h44: get_sbox_val = 8'h1b; 8'h45: get_sbox_val = 8'h6e; 8'h46: get_sbox_val = 8'h5a; 8'h47: get_sbox_val = 8'ha0;
        8'h48: get_sbox_val = 8'h52; 8'h49: get_sbox_val = 8'h3b; 8'h4a: get_sbox_val = 8'hd6; 8'h4b: get_sbox_val = 8'hb3;
        8'h4c: get_sbox_val = 8'h29; 8'h4d: get_sbox_val = 8'he3; 8'h4e: get_sbox_val = 8'h2f; 8'h4f: get_sbox_val = 8'h84;
        8'h50: get_sbox_val = 8'h53; 8'h51: get_sbox_val = 8'hd1; 8'h52: get_sbox_val = 8'h00; 8'h53: get_sbox_val = 8'hed;
        8'h54: get_sbox_val = 8'h20; 8'h55: get_sbox_val = 8'hfc; 8'h56: get_sbox_val = 8'hb1; 8'h57: get_sbox_val = 8'h5b;
        8'h58: get_sbox_val = 8'h6a; 8'h59: get_sbox_val = 8'hcb; 8'h5a: get_sbox_val = 8'hbe; 8'h5b: get_sbox_val = 8'h39;
        8'h5c: get_sbox_val = 8'h4a; 8'h5d: get_sbox_val = 8'h4c; 8'h5e: get_sbox_val = 8'h58; 8'h5f: get_sbox_val = 8'hcf;
        8'h60: get_sbox_val = 8'hd0; 8'h61: get_sbox_val = 8'hef; 8'h62: get_sbox_val = 8'haa; 8'h63: get_sbox_val = 8'hfb;
        8'h64: get_sbox_val = 8'h43; 8'h65: get_sbox_val = 8'h4d; 8'h66: get_sbox_val = 8'h33; 8'h67: get_sbox_val = 8'h85;
        8'h68: get_sbox_val = 8'h45; 8'h69: get_sbox_val = 8'hf9; 8'h6a: get_sbox_val = 8'h02; 8'h6b: get_sbox_val = 8'h7f;
        8'h6c: get_sbox_val = 8'h50; 8'h6d: get_sbox_val = 8'h3c; 8'h6e: get_sbox_val = 8'h9f; 8'h6f: get_sbox_val = 8'ha8;
        8'h70: get_sbox_val = 8'h51; 8'h71: get_sbox_val = 8'ha3; 8'h72: get_sbox_val = 8'h40; 8'h73: get_sbox_val = 8'h8f;
        8'h74: get_sbox_val = 8'h92; 8'h75: get_sbox_val = 8'h9d; 8'h76: get_sbox_val = 8'h38; 8'h77: get_sbox_val = 8'hf5;
        8'h78: get_sbox_val = 8'hbc; 8'h79: get_sbox_val = 8'hb6; 8'h7a: get_sbox_val = 8'hda; 8'h7b: get_sbox_val = 8'h21;
        8'h7c: get_sbox_val = 8'h10; 8'h7d: get_sbox_val = 8'hff; 8'h7e: get_sbox_val = 8'hf3; 8'h7f: get_sbox_val = 8'hd2;
        8'h80: get_sbox_val = 8'hcd; 8'h81: get_sbox_val = 8'h0c; 8'h82: get_sbox_val = 8'h13; 8'h83: get_sbox_val = 8'hec;
        8'h84: get_sbox_val = 8'h5f; 8'h85: get_sbox_val = 8'h97; 8'h86: get_sbox_val = 8'h44; 8'h87: get_sbox_val = 8'h17;
        8'h88: get_sbox_val = 8'hc4; 8'h89: get_sbox_val = 8'ha7; 8'h8a: get_sbox_val = 8'h7e; 8'h8b: get_sbox_val = 8'h3d;
        8'h8c: get_sbox_val = 8'h64; 8'h8d: get_sbox_val = 8'h5d; 8'h8e: get_sbox_val = 8'h19; 8'h8f: get_sbox_val = 8'h73;
        8'h90: get_sbox_val = 8'h60; 8'h91: get_sbox_val = 8'h81; 8'h92: get_sbox_val = 8'h4f; 8'h93: get_sbox_val = 8'hdc;
        8'h94: get_sbox_val = 8'h22; 8'h95: get_sbox_val = 8'h2a; 8'h96: get_sbox_val = 8'h90; 8'h97: get_sbox_val = 8'h88;
        8'h98: get_sbox_val = 8'h46; 8'h99: get_sbox_val = 8'hee; 8'h9a: get_sbox_val = 8'hb8; 8'h9b: get_sbox_val = 8'h14;
        8'h9c: get_sbox_val = 8'hde; 8'h9d: get_sbox_val = 8'h5e; 8'h9e: get_sbox_val = 8'h0b; 8'h9f: get_sbox_val = 8'hdb;
        8'ha0: get_sbox_val = 8'he0; 8'ha1: get_sbox_val = 8'h32; 8'ha2: get_sbox_val = 8'h3a; 8'ha3: get_sbox_val = 8'h0a;
        8'ha4: get_sbox_val = 8'h49; 8'ha5: get_sbox_val = 8'h06; 8'ha6: get_sbox_val = 8'h24; 8'ha7: get_sbox_val = 8'h5c;
        8'ha8: get_sbox_val = 8'hc2; 8'ha9: get_sbox_val = 8'hd3; 8'haa: get_sbox_val = 8'hac; 8'hab: get_sbox_val = 8'h62;
        8'hac: get_sbox_val = 8'h91; 8'had: get_sbox_val = 8'h95; 8'hae: get_sbox_val = 8'he4; 8'haf: get_sbox_val = 8'h79;
        8'hb0: get_sbox_val = 8'he7; 8'hb1: get_sbox_val = 8'hc8; 8'hb2: get_sbox_val = 8'h37; 8'hb3: get_sbox_val = 8'h6d;
        8'hb4: get_sbox_val = 8'h8d; 8'hb5: get_sbox_val = 8'hd5; 8'hb6: get_sbox_val = 8'h4e; 8'hb7: get_sbox_val = 8'ha9;
        8'hb8: get_sbox_val = 8'h6c; 8'hb9: get_sbox_val = 8'h56; 8'hba: get_sbox_val = 8'hf4; 8'hbb: get_sbox_val = 8'hea;
        8'hbc: get_sbox_val = 8'h65; 8'hbd: get_sbox_val = 8'h7a; 8'hbe: get_sbox_val = 8'hae; 8'hbf: get_sbox_val = 8'h08;
        8'hc0: get_sbox_val = 8'hba; 8'hc1: get_sbox_val = 8'h78; 8'hc2: get_sbox_val = 8'h25; 8'hc3: get_sbox_val = 8'h2e;
        8'hc4: get_sbox_val = 8'h1c; 8'hc5: get_sbox_val = 8'ha6; 8'hc6: get_sbox_val = 8'hb4; 8'hc7: get_sbox_val = 8'hc6;
        8'hc8: get_sbox_val = 8'he8; 8'hc9: get_sbox_val = 8'hdd; 8'hca: get_sbox_val = 8'h74; 8'hcb: get_sbox_val = 8'h1f;
        8'hcc: get_sbox_val = 8'h4b; 8'hcd: get_sbox_val = 8'hbd; 8'hce: get_sbox_val = 8'h8b; 8'hcf: get_sbox_val = 8'h8a;
        8'hd0: get_sbox_val = 8'h70; 8'hd1: get_sbox_val = 8'h3e; 8'hd2: get_sbox_val = 8'hb5; 8'hd3: get_sbox_val = 8'h66;
        8'hd4: get_sbox_val = 8'h48; 8'hd5: get_sbox_val = 8'h03; 8'hd6: get_sbox_val = 8'hf6; 8'hd7: get_sbox_val = 8'h0e;
        8'hd8: get_sbox_val = 8'h61; 8'hd9: get_sbox_val = 8'h35; 8'hda: get_sbox_val = 8'h57; 8'hdb: get_sbox_val = 8'hb9;
        8'hdc: get_sbox_val = 8'h86; 8'hdd: get_sbox_val = 8'hc1; 8'hde: get_sbox_val = 8'h1d; 8'hdf: get_sbox_val = 8'h9e;
        8'he0: get_sbox_val = 8'he1; 8'he1: get_sbox_val = 8'hf8; 8'he2: get_sbox_val = 8'h98; 8'he3: get_sbox_val = 8'h11;
        8'he4: get_sbox_val = 8'h69; 8'he5: get_sbox_val = 8'hd9; 8'he6: get_sbox_val = 8'h8e; 8'he7: get_sbox_val = 8'h94;
        8'he8: get_sbox_val = 8'h9b; 8'he9: get_sbox_val = 8'h1e; 8'hea: get_sbox_val = 8'h87; 8'heb: get_sbox_val = 8'he9;
        8'hec: get_sbox_val = 8'hce; 8'hed: get_sbox_val = 8'h55; 8'hee: get_sbox_val = 8'h28; 8'hef: get_sbox_val = 8'hdf;
        8'hf0: get_sbox_val = 8'h8c; 8'hf1: get_sbox_val = 8'ha1; 8'hf2: get_sbox_val = 8'h89; 8'hf3: get_sbox_val = 8'h0d;
        8'hf4: get_sbox_val = 8'hbf; 8'hf5: get_sbox_val = 8'he6; 8'hf6: get_sbox_val = 8'h42; 8'hf7: get_sbox_val = 8'h68;
        8'hf8: get_sbox_val = 8'h41; 8'hf9: get_sbox_val = 8'h99; 8'hfa: get_sbox_val = 8'h2d; 8'hfb: get_sbox_val = 8'h0f;
        8'hfc: get_sbox_val = 8'hb0; 8'hfd: get_sbox_val = 8'h54; 8'hfe: get_sbox_val = 8'hbb; 8'hff: get_sbox_val = 8'h16;
        default: get_sbox_val = 8'h00;
    endcase
  endfunction

  function automatic [127:0] f_subbytes(input [127:0] x);
    integer j;
    begin
      f_subbytes = 128'b0;
      for (j = 0; j < 16; j = j + 1) begin
        
        f_subbytes[127 - j*8 -: 8] = get_sbox_val(x[127 - j*8 -: 8]);
      end
    end
  endfunction

  function automatic [127:0] f_shiftrows(input [127:0] x);
    reg [127:0] t;
    begin
      t[127:120] = x[127:120];
      t[95:88]   = x[95:88];
      t[63:56]   = x[63:56];
      t[31:24]   = x[31:24];

      t[119:112] = x[87:80];
      t[87:80]   = x[55:48];
      t[55:48]   = x[23:16];
      t[23:16]   = x[119:112];

      t[111:104] = x[47:40];
      t[79:72]   = x[15:8];
      t[47:40]   = x[111:104];
      t[15:8]    = x[79:72];

      t[103:96]  = x[7:0];
      t[71:64]   = x[103:96];
      t[39:32]   = x[71:64];
      t[7:0]     = x[39:32];

      f_shiftrows = t;
    end
  endfunction

  function automatic [127:0] f_mixcolumns(input [127:0] x);
    reg [7:0] s [0:15];
    reg [7:0] outb [0:15];
    integer k;
    begin
      for (k = 0; k < 16; k = k + 1)
        s[k] = x[127 - k*8 -: 8];

      outb[0]  = mulTwo(s[0])  ^ mulThree(s[1])  ^ s[2]         ^ s[3];
      outb[1]  = s[0]         ^ mulTwo(s[1])    ^ mulThree(s[2])^ s[3];
      outb[2]  = s[0]         ^ s[1]            ^ mulTwo(s[2])  ^ mulThree(s[3]);
      outb[3]  = mulThree(s[0])^ s[1]            ^ s[2]         ^ mulTwo(s[3]);

      outb[4]  = mulTwo(s[4])  ^ mulThree(s[5])  ^ s[6]         ^ s[7];
      outb[5]  = s[4]         ^ mulTwo(s[5])    ^ mulThree(s[6])^ s[7];
      outb[6]  = s[4]         ^ s[5]            ^ mulTwo(s[6])  ^ mulThree(s[7]);
      outb[7]  = mulThree(s[4])^ s[5]            ^ s[6]         ^ mulTwo(s[7]);

      outb[8]  = mulTwo(s[8])  ^ mulThree(s[9])  ^ s[10]        ^ s[11];
      outb[9]  = s[8]         ^ mulTwo(s[9])    ^ mulThree(s[10])^ s[11];
      outb[10] = s[8]         ^ s[9]            ^ mulTwo(s[10]) ^ mulThree(s[11]);
      outb[11] = mulThree(s[8])^ s[9]            ^ s[10]        ^ mulTwo(s[11]);

      outb[12] = mulTwo(s[12]) ^ mulThree(s[13]) ^ s[14]        ^ s[15];
      outb[13] = s[12]        ^ mulTwo(s[13])   ^ mulThree(s[14])^ s[15];
      outb[14] = s[12]        ^ s[13]           ^ mulTwo(s[14])  ^ mulThree(s[15]);
      outb[15] = mulThree(s[12])^ s[13]           ^ s[14]         ^ mulTwo(s[15]);

      f_mixcolumns = 128'b0;
      for (k = 0; k < 16; k = k + 1)
        f_mixcolumns[127 - k*8 -: 8] = outb[k];
    end
  endfunction

  function automatic [127:0] round_math(input [127:0] s);
    round_math = f_mixcolumns(f_shiftrows(f_subbytes(s)));
  endfunction

  reg [127:0] expected_state;
  reg [127:0] expected_cipher;
  integer i;

  task tick;
    begin
      @(negedge clk);
      #1;
      @(posedge clk);
      #1;
    end
  endtask

  task check128;
    input [127:0] got;
    input [127:0] exp;
    input [128*8:1] tag;
    begin
      if (got !== exp) begin
        $display("FAIL %0s -- got %032x expected %032x", tag, got, exp);
        $finish;
      end
    end
  endtask

  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  initial begin
    reset = 1;
    count = 5'd0;
    encryption_engine_data = 128'h00112233445566778899aabbccddeeff;
    round_key = 128'h01010101010101010101010101010101;
    expected_state = 128'b0;
    expected_cipher = 128'b0;

    #20;
    reset = 0;
    #10;

    // count=0: idle
    count = 5'd0;
    tick();
    check128(dut.state_reg, 128'b0, "count=0 holds state");
    check128(cipher, 128'b0, "count=0 holds cipher");

    // count=1: init AddRoundKey only (init+A1 combine was dropped — see Task 3 notes)
    count = 5'd1;
    tick();
    expected_state = encryption_engine_data ^ round_key;
    check128(dut.state_reg, expected_state, "count=1 init addroundkey");

    // Round 1: counts 2 (phase A) / 3 (phase B1: sr_reg) / 4 (phase B2: state_reg <= mc^key)
    // round_key for phase B2 must be RK1 — set it before count=4 ticks.
    round_key = 128'h02020202020202020202020202020202;
    count = 5'd2;  tick();   // phase A: sub_out_hi captured
    count = 5'd3;  tick();   // phase B1: sr_reg captured
    count = 5'd4;  tick();   // phase B2: state_reg <= mc(sr_reg) ^ round_key
    expected_state = round_math(expected_state) ^ round_key;
    check128(dut.state_reg, expected_state, "round1 (count=2,3,4)");

    // Round 2: counts 5 / 6 / 7
    round_key = 128'h03030303030303030303030303030303;
    count = 5'd5;  tick();
    count = 5'd6;  tick();
    count = 5'd7;  tick();
    expected_state = round_math(expected_state) ^ round_key;
    check128(dut.state_reg, expected_state, "round2 (count=5,6,7)");

    // Skip rounds 3..8 (run them without checking) so we land on the right state for R9.
    // Each round = 3 cycles (A, B1, B2). Track expected_state through f_round.
    for (i = 3; i <= 8; i = i + 1) begin
      round_key = {16{i[7:0]}};
      count = 5'd2 + (i - 1) * 3;       // phase A
      tick();
      count = 5'd3 + (i - 1) * 3;       // phase B1
      tick();
      count = 5'd4 + (i - 1) * 3;       // phase B2
      tick();
      expected_state = round_math(expected_state) ^ round_key;
    end

    // Round 9: counts 26 / 27 / 28
    round_key = 128'h0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a;
    count = 5'd26; tick();
    count = 5'd27; tick();
    count = 5'd28; tick();
    expected_state = round_math(expected_state) ^ round_key;
    check128(dut.state_reg, expected_state, "round9 (count=26,27,28)");

    // Round 10 (final): counts 29 (A) / 30 (B — no MixColumns, no pipeline split)
    round_key = 128'h0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b;
    count = 5'd29; tick();   // final A: sub_out_hi captured
    count = 5'd30; tick();   // final B: state_reg <= sr ^ round_key
    expected_state = f_shiftrows(f_subbytes(expected_state)) ^ round_key;
    expected_cipher = expected_state;
    check128(dut.state_reg, expected_state, "final round (count=29,30)");
    check128(cipher, expected_cipher, "cipher at count=30");

    // Return to idle
    count = 5'd0;
    tick();
    check128(dut.state_reg, expected_state, "after wrap state holds");
    check128(cipher, expected_cipher, "after wrap cipher holds");

    // Reset test
    reset = 1;
    #10;
    reset = 0;
    tick();
    check128(dut.state_reg, 128'b0, "reset clears state");
    check128(cipher, 128'b0, "reset clears cipher");

    $display("PASS");
    $finish;
  end

endmodule
