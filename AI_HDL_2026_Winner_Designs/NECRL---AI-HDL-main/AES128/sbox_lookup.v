/*
 * AES S-box using Canright Galois-field composite-field arithmetic
 * From coruus/canright-aes-sboxes (unmasked sbox.verilog)
 * ~30-50% area reduction vs 256-byte LUT, similar or better timing
 * Same interface: addr in, out (SubBytes result)
 */
module sbox_lookup (
    input  wire [7:0] addr,
    output wire [7:0] out
);
    bSbox u_sbox (.A(addr), .encrypt(1'b1), .Q(out));
endmodule

/* --- Canright GF S-box (unmasked) --- */

module GF_SQ_2 ( input [1:0] A, output [1:0] Q );
    assign Q = { A[0], A[1] };
endmodule

module GF_SCLW_2 ( input [1:0] A, output [1:0] Q );
    assign Q = { (A[1] ^ A[0]), A[1] };
endmodule

module GF_SCLW2_2 ( input [1:0] A, output [1:0] Q );
    assign Q = { A[0], (A[1] ^ A[0]) };
endmodule

module GF_MULS_2 ( input [1:0] A, input ab, input [1:0] B, input cd, output [1:0] Q );
    wire abcd, p, q;
    assign abcd = ~(ab & cd);
    assign p = (~(A[1] & B[1])) ^ abcd;
    assign q = (~(A[0] & B[0])) ^ abcd;
    assign Q = { p, q };
endmodule

module GF_MULS_SCL_2 ( input [1:0] A, input ab, input [1:0] B, input cd, output [1:0] Q );
    wire t, p, q;
    assign t = ~(A[0] & B[0]);
    assign p = (~(ab & cd)) ^ t;
    assign q = (~(A[1] & B[1])) ^ t;
    assign Q = { p, q };
endmodule

module GF_INV_4 ( input [3:0] A, output [3:0] Q );
    wire [1:0] a, b, c, d, p, q;
    wire sa, sb, sd;
    assign a = A[3:2];
    assign b = A[1:0];
    assign sa = a[1] ^ a[0];
    assign sb = b[1] ^ b[0];
    assign c = {
        ~(a[1] | b[1]) ^ (~(sa & sb)),
        ~(sa | sb) ^ (~(a[0] & b[0]))
    };
    GF_SQ_2 dsq (.A(c), .Q(d));
    assign sd = d[1] ^ d[0];
    GF_MULS_2 pmul (.A(d), .ab(sd), .B(b), .cd(sb), .Q(p));
    GF_MULS_2 qmul (.A(d), .ab(sd), .B(a), .cd(sa), .Q(q));
    assign Q = { p, q };
endmodule

module GF_SQ_SCL_4 ( input [3:0] A, output [3:0] Q );
    wire [1:0] a, b, ab2, b2, b2N2;
    assign a = A[3:2];
    assign b = A[1:0];
    GF_SQ_2 absq (.A(a ^ b), .Q(ab2));
    GF_SQ_2 bsq (.A(b), .Q(b2));
    GF_SCLW_2 bmulN2 (.A(b2), .Q(b2N2));
    assign Q = { ab2, b2N2 };
endmodule

module GF_MULS_4 (
    input [3:0] A, input [1:0] a, input Al, input Ah, input aa,
    input [3:0] B, input [1:0] b, input Bl, input Bh, input bb,
    output [3:0] Q
);
    wire [1:0] ph, pl, p;
    GF_MULS_2 himul (.A(A[3:2]), .ab(Ah), .B(B[3:2]), .cd(Bh), .Q(ph));
    GF_MULS_2 lomul (.A(A[1:0]), .ab(Al), .B(B[1:0]), .cd(Bl), .Q(pl));
    GF_MULS_SCL_2 summul (.A(a), .ab(aa), .B(b), .cd(bb), .Q(p));
    assign Q = { (ph ^ p), (pl ^ p) };
endmodule

module GF_INV_8 ( input [7:0] A, output [7:0] Q );
    wire [3:0] a, b, c, d, p, q;
    wire [1:0] sa, sb, sd;
    wire al, ah, aa, bl, bh, bb, dl, dh, dd;
    wire c1, c2, c3;
    assign a = A[7:4];
    assign b = A[3:0];
    assign sa = a[3:2] ^ a[1:0];
    assign sb = b[3:2] ^ b[1:0];
    assign al = a[1] ^ a[0];
    assign ah = a[3] ^ a[2];
    assign aa = sa[1] ^ sa[0];
    assign bl = b[1] ^ b[0];
    assign bh = b[3] ^ b[2];
    assign bb = sb[1] ^ sb[0];
    assign c1 = ~(ah & bh);
    assign c2 = ~(sa[0] & sb[0]);
    assign c3 = ~(aa & bb);
    assign c = {
        (~(sa[0] | sb[0]) ^ (~(a[3] & b[3]))) ^ c1 ^ c3,
        (~(sa[1] | sb[1]) ^ (~(a[2] & b[2]))) ^ c1 ^ c2,
        (~(al | bl) ^ (~(a[1] & b[1]))) ^ c2 ^ c3,
        (~(a[0] | b[0]) ^ (~(al & bl))) ^ (~(sa[1] & sb[1])) ^ c2
    };
    GF_INV_4 dinv (.A(c), .Q(d));
    assign sd = d[3:2] ^ d[1:0];
    assign dl = d[1] ^ d[0];
    assign dh = d[3] ^ d[2];
    assign dd = sd[1] ^ sd[0];
    GF_MULS_4 pmul (.A(d), .a(sd), .Al(dl), .Ah(dh), .aa(dd),
                    .B(b), .b(sb), .Bl(bl), .Bh(bh), .bb(bb), .Q(p));
    GF_MULS_4 qmul (.A(d), .a(sd), .Al(dl), .Ah(dh), .aa(dd),
                    .B(a), .b(sa), .Bl(al), .Bh(ah), .bb(aa), .Q(q));
    assign Q = { p, q };
endmodule

module MUX21I ( input A, input B, input s, output Q );
    assign Q = ~(s ? A : B);
endmodule

module SELECT_NOT_8 ( input [7:0] A, input [7:0] B, input s, output [7:0] Q );
    MUX21I m7 (.A(A[7]), .B(B[7]), .s(s), .Q(Q[7]));
    MUX21I m6 (.A(A[6]), .B(B[6]), .s(s), .Q(Q[6]));
    MUX21I m5 (.A(A[5]), .B(B[5]), .s(s), .Q(Q[5]));
    MUX21I m4 (.A(A[4]), .B(B[4]), .s(s), .Q(Q[4]));
    MUX21I m3 (.A(A[3]), .B(B[3]), .s(s), .Q(Q[3]));
    MUX21I m2 (.A(A[2]), .B(B[2]), .s(s), .Q(Q[2]));
    MUX21I m1 (.A(A[1]), .B(B[1]), .s(s), .Q(Q[1]));
    MUX21I m0 (.A(A[0]), .B(B[0]), .s(s), .Q(Q[0]));
endmodule

module bSbox ( input [7:0] A, input encrypt, output [7:0] Q );
    wire [7:0] B, C, D, X, Y, Z;
    wire R1, R2, R3, R4, R5, R6, R7, R8, R9;
    wire T1, T2, T3, T4, T5, T6, T7, T8, T9, T10;
    assign R1 = A[7] ^ A[5];
    assign R2 = A[7] ~^ A[4];
    assign R3 = A[6] ^ A[0];
    assign R4 = A[5] ~^ R3;
    assign R5 = A[4] ^ R4;
    assign R6 = A[3] ^ A[0];
    assign R7 = A[2] ^ R1;
    assign R8 = A[1] ^ R3;
    assign R9 = A[3] ^ R8;
    assign B[7] = R7 ~^ R8;
    assign B[6] = R5;
    assign B[5] = A[1] ^ R4;
    assign B[4] = R1 ~^ R3;
    assign B[3] = A[1] ^ R2 ^ R6;
    assign B[2] = ~A[0];
    assign B[1] = R4;
    assign B[0] = A[2] ~^ R9;
    assign Y[7] = R2;
    assign Y[6] = A[4] ^ R8;
    assign Y[5] = A[6] ^ A[4];
    assign Y[4] = R9;
    assign Y[3] = A[6] ~^ R2;
    assign Y[2] = R7;
    assign Y[1] = A[4] ^ R6;
    assign Y[0] = A[1] ^ R5;
    SELECT_NOT_8 sel_in (.A(B), .B(Y), .s(encrypt), .Q(Z));
    GF_INV_8 inv (.A(Z), .Q(C));
    assign T1 = C[7] ^ C[3];
    assign T2 = C[6] ^ C[4];
    assign T3 = C[6] ^ C[0];
    assign T4 = C[5] ~^ C[3];
    assign T5 = C[5] ~^ T1;
    assign T6 = C[5] ~^ C[1];
    assign T7 = C[4] ~^ T6;
    assign T8 = C[2] ^ T4;
    assign T9 = C[1] ^ T2;
    assign T10 = T3 ^ T5;
    assign D[7] = T4;
    assign D[6] = T1;
    assign D[5] = T3;
    assign D[4] = T5;
    assign D[3] = T2 ^ T5;
    assign D[2] = T3 ^ T8;
    assign D[1] = T7;
    assign D[0] = T9;
    assign X[7] = C[4] ~^ C[1];
    assign X[6] = C[1] ^ T10;
    assign X[5] = C[2] ^ T10;
    assign X[4] = C[6] ~^ C[1];
    assign X[3] = T8 ^ T9;
    assign X[2] = C[7] ~^ T7;
    assign X[1] = T6;
    assign X[0] = ~C[2];
    SELECT_NOT_8 sel_out (.A(D), .B(X), .s(encrypt), .Q(Q));
endmodule
