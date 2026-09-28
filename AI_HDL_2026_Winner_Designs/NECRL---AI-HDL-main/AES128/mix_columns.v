(* keep_hierarchy = "yes" *)
module mix_columns (
    input  [127:0] data_in,
    output [127:0] data_out
);

  function automatic [7:0] mulTwo(input [7:0] byte_in);
    if (byte_in[7])
      mulTwo = (byte_in << 1) ^ 8'h1b;
    else
      mulTwo = (byte_in << 1);
  endfunction

  function automatic [7:0] mulThree(input [7:0] byte_in);
    mulThree = mulTwo(byte_in) ^ byte_in;
  endfunction

  assign data_out[127:120] = mulTwo(data_in[127:120]) ^ mulThree(data_in[119:112]) ^ data_in[111:104] ^ data_in[103:96];
  assign data_out[119:112] = data_in[127:120] ^ mulTwo(data_in[119:112]) ^ mulThree(data_in[111:104]) ^ data_in[103:96];
  assign data_out[111:104] = data_in[127:120] ^ data_in[119:112] ^ mulTwo(data_in[111:104]) ^ mulThree(data_in[103:96]);
  assign data_out[103:96]  = mulThree(data_in[127:120]) ^ data_in[119:112] ^ data_in[111:104] ^ mulTwo(data_in[103:96]);

  assign data_out[95:88]   = mulTwo(data_in[95:88]) ^ mulThree(data_in[87:80]) ^ data_in[79:72] ^ data_in[71:64];
  assign data_out[87:80]   = data_in[95:88] ^ mulTwo(data_in[87:80]) ^ mulThree(data_in[79:72]) ^ data_in[71:64];
  assign data_out[79:72]   = data_in[95:88] ^ data_in[87:80] ^ mulTwo(data_in[79:72]) ^ mulThree(data_in[71:64]);
  assign data_out[71:64]   = mulThree(data_in[95:88]) ^ data_in[87:80] ^ data_in[79:72] ^ mulTwo(data_in[71:64]);

  assign data_out[63:56]   = mulTwo(data_in[63:56]) ^ mulThree(data_in[55:48]) ^ data_in[47:40] ^ data_in[39:32];
  assign data_out[55:48]   = data_in[63:56] ^ mulTwo(data_in[55:48]) ^ mulThree(data_in[47:40]) ^ data_in[39:32];
  assign data_out[47:40]   = data_in[63:56] ^ data_in[55:48] ^ mulTwo(data_in[47:40]) ^ mulThree(data_in[39:32]);
  assign data_out[39:32]   = mulThree(data_in[63:56]) ^ data_in[55:48] ^ data_in[47:40] ^ mulTwo(data_in[39:32]);

  assign data_out[31:24]   = mulTwo(data_in[31:24]) ^ mulThree(data_in[23:16]) ^ data_in[15:8] ^ data_in[7:0];
  assign data_out[23:16]   = data_in[31:24] ^ mulTwo(data_in[23:16]) ^ mulThree(data_in[15:8]) ^ data_in[7:0];
  assign data_out[15:8]    = data_in[31:24] ^ data_in[23:16] ^ mulTwo(data_in[15:8]) ^ mulThree(data_in[7:0]);
  assign data_out[7:0]     = mulThree(data_in[31:24]) ^ data_in[23:16] ^ data_in[15:8] ^ mulTwo(data_in[7:0]);

endmodule
