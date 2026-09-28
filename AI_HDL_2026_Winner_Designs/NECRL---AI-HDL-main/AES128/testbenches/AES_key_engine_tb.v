`timescale 1ns / 1ps

module AES_key_engine_tb;

    // =========================================================================
    // 1. DUT Connections
    // =========================================================================
    reg clk;
    reg reset;
    reg key_engine_start;
    reg [127:0] original_key;
    wire [127:0] round_key;

    AES_key_engine uut (
        .clk(clk),
        .reset(reset),
        .stall(1'b0),
        .count(5'd0),                  // drive count=0 so key_hold is never asserted;
                                       // tests the engine's natural 2-cycle pacing.
                                       // (Integration timing with key_hold is covered
                                       // by AES_peripheral_tb.)
        .key_engine_start(key_engine_start),
        .original_key(original_key),
        .round_key(round_key)
    );

    // =========================================================================
    // 2. Behavioral Golden Model (The Reference Logic)
    // =========================================================================
    
    // Memory to hold the "Golden" S-Box
    reg [7:0] sbox_ref [0:255]; 

    // Initialize the S-Box with standard AES values
    initial begin
        // Row 0
        sbox_ref[0] = 8'h63; sbox_ref[1] = 8'h7c; sbox_ref[2] = 8'h77; sbox_ref[3] = 8'h7b;
        sbox_ref[4] = 8'hf2; sbox_ref[5] = 8'h6b; sbox_ref[6] = 8'h6f; sbox_ref[7] = 8'hc5;
        sbox_ref[8] = 8'h30; sbox_ref[9] = 8'h01; sbox_ref[10]= 8'h67; sbox_ref[11]= 8'h2b;
        sbox_ref[12]= 8'hfe; sbox_ref[13]= 8'hd7; sbox_ref[14]= 8'hab; sbox_ref[15]= 8'h76;
        // Row 1
        sbox_ref[16]= 8'hca; sbox_ref[17]= 8'h82; sbox_ref[18]= 8'hc9; sbox_ref[19]= 8'h7d;
        sbox_ref[20]= 8'hfa; sbox_ref[21]= 8'h59; sbox_ref[22]= 8'h47; sbox_ref[23]= 8'hf0;
        sbox_ref[24]= 8'had; sbox_ref[25]= 8'hd4; sbox_ref[26]= 8'ha2; sbox_ref[27]= 8'haf;
        sbox_ref[28]= 8'h9c; sbox_ref[29]= 8'ha4; sbox_ref[30]= 8'h72; sbox_ref[31]= 8'hc0;
        // Row 2
        sbox_ref[32]= 8'hb7; sbox_ref[33]= 8'hfd; sbox_ref[34]= 8'h93; sbox_ref[35]= 8'h26;
        sbox_ref[36]= 8'h36; sbox_ref[37]= 8'h3f; sbox_ref[38]= 8'hf7; sbox_ref[39]= 8'hcc;
        sbox_ref[40]= 8'h34; sbox_ref[41]= 8'ha5; sbox_ref[42]= 8'he5; sbox_ref[43]= 8'hf1;
        sbox_ref[44]= 8'h71; sbox_ref[45]= 8'hd8; sbox_ref[46]= 8'h31; sbox_ref[47]= 8'h15;
        // Row 3
        sbox_ref[48]= 8'h04; sbox_ref[49]= 8'hc7; sbox_ref[50]= 8'h23; sbox_ref[51]= 8'hc3;
        sbox_ref[52]= 8'h18; sbox_ref[53]= 8'h96; sbox_ref[54]= 8'h05; sbox_ref[55]= 8'h9a;
        sbox_ref[56]= 8'h07; sbox_ref[57]= 8'h12; sbox_ref[58]= 8'h80; sbox_ref[59]= 8'he2;
        sbox_ref[60]= 8'heb; sbox_ref[61]= 8'h27; sbox_ref[62]= 8'hb2; sbox_ref[63]= 8'h75;
        // Row 4
        sbox_ref[64]= 8'h09; sbox_ref[65]= 8'h83; sbox_ref[66]= 8'h2c; sbox_ref[67]= 8'h1a;
        sbox_ref[68]= 8'h1b; sbox_ref[69]= 8'h6e; sbox_ref[70]= 8'h5a; sbox_ref[71]= 8'ha0;
        sbox_ref[72]= 8'h52; sbox_ref[73]= 8'h3b; sbox_ref[74]= 8'hd6; sbox_ref[75]= 8'hb3;
        sbox_ref[76]= 8'h29; sbox_ref[77]= 8'he3; sbox_ref[78]= 8'h2f; sbox_ref[79]= 8'h84;
        // Row 5
        sbox_ref[80]= 8'h53; sbox_ref[81]= 8'hd1; sbox_ref[82]= 8'h00; sbox_ref[83]= 8'hed;
        sbox_ref[84]= 8'h20; sbox_ref[85]= 8'hfc; sbox_ref[86]= 8'hb1; sbox_ref[87]= 8'h5b;
        sbox_ref[88]= 8'h6a; sbox_ref[89]= 8'hcb; sbox_ref[90]= 8'hbe; sbox_ref[91]= 8'h39;
        sbox_ref[92]= 8'h4a; sbox_ref[93]= 8'h4c; sbox_ref[94]= 8'h58; sbox_ref[95]= 8'hcf;
        // Row 6
        sbox_ref[96]= 8'hd0; sbox_ref[97]= 8'hef; sbox_ref[98]= 8'haa; sbox_ref[99]= 8'hfb;
        sbox_ref[100]=8'h43; sbox_ref[101]=8'h4d; sbox_ref[102]=8'h33; sbox_ref[103]=8'h85;
        sbox_ref[104]=8'h45; sbox_ref[105]=8'hf9; sbox_ref[106]=8'h02; sbox_ref[107]=8'h7f;
        sbox_ref[108]=8'h50; sbox_ref[109]=8'h3c; sbox_ref[110]=8'h9f; sbox_ref[111]=8'ha8;
        // Row 7
        sbox_ref[112]=8'h51; sbox_ref[113]=8'ha3; sbox_ref[114]=8'h40; sbox_ref[115]=8'h8f;
        sbox_ref[116]=8'h92; sbox_ref[117]=8'h9d; sbox_ref[118]=8'h38; sbox_ref[119]=8'hf5;
        sbox_ref[120]=8'hbc; sbox_ref[121]=8'hb6; sbox_ref[122]=8'hda; sbox_ref[123]=8'h21;
        sbox_ref[124]=8'h10; sbox_ref[125]=8'hff; sbox_ref[126]=8'hf3; sbox_ref[127]=8'hd2;
        // Row 8
        sbox_ref[128]=8'hcd; sbox_ref[129]=8'h0c; sbox_ref[130]=8'h13; sbox_ref[131]=8'hec;
        sbox_ref[132]=8'h5f; sbox_ref[133]=8'h97; sbox_ref[134]=8'h44; sbox_ref[135]=8'h17;
        sbox_ref[136]=8'hc4; sbox_ref[137]=8'ha7; sbox_ref[138]=8'h7e; sbox_ref[139]=8'h3d;
        sbox_ref[140]=8'h64; sbox_ref[141]=8'h5d; sbox_ref[142]=8'h19; sbox_ref[143]=8'h73;
        // Row 9
        sbox_ref[144]=8'h60; sbox_ref[145]=8'h81; sbox_ref[146]=8'h4f; sbox_ref[147]=8'hdc;
        sbox_ref[148]=8'h22; sbox_ref[149]=8'h2a; sbox_ref[150]=8'h90; sbox_ref[151]=8'h88;
        sbox_ref[152]=8'h46; sbox_ref[153]=8'hee; sbox_ref[154]=8'hb8; sbox_ref[155]=8'h14;
        sbox_ref[156]=8'hde; sbox_ref[157]=8'h5e; sbox_ref[158]=8'h0b; sbox_ref[159]=8'hdb;
        // Row A
        sbox_ref[160]=8'he0; sbox_ref[161]=8'h32; sbox_ref[162]=8'h3a; sbox_ref[163]=8'h0a;
        sbox_ref[164]=8'h49; sbox_ref[165]=8'h06; sbox_ref[166]=8'h24; sbox_ref[167]=8'h5c;
        sbox_ref[168]=8'hc2; sbox_ref[169]=8'hd3; sbox_ref[170]=8'hac; sbox_ref[171]=8'h62;
        sbox_ref[172]=8'h91; sbox_ref[173]=8'h95; sbox_ref[174]=8'he4; sbox_ref[175]=8'h79;
        // Row B
        sbox_ref[176]=8'he7; sbox_ref[177]=8'hc8; sbox_ref[178]=8'h37; sbox_ref[179]=8'h6d;
        sbox_ref[180]=8'h8d; sbox_ref[181]=8'hd5; sbox_ref[182]=8'h4e; sbox_ref[183]=8'ha9;
        sbox_ref[184]=8'h6c; sbox_ref[185]=8'h56; sbox_ref[186]=8'hf4; sbox_ref[187]=8'hea;
        sbox_ref[188]=8'h65; sbox_ref[189]=8'h7a; sbox_ref[190]=8'hae; sbox_ref[191]=8'h08;
        // Row C
        sbox_ref[192]=8'hba; sbox_ref[193]=8'h78; sbox_ref[194]=8'h25; sbox_ref[195]=8'h2e;
        sbox_ref[196]=8'h1c; sbox_ref[197]=8'ha6; sbox_ref[198]=8'hb4; sbox_ref[199]=8'hc6;
        sbox_ref[200]=8'he8; sbox_ref[201]=8'hdd; sbox_ref[202]=8'h74; sbox_ref[203]=8'h1f;
        sbox_ref[204]=8'h4b; sbox_ref[205]=8'hbd; sbox_ref[206]=8'h8b; sbox_ref[207]=8'h8a;
        // Row D
        sbox_ref[208]=8'h70; sbox_ref[209]=8'h3e; sbox_ref[210]=8'hb5; sbox_ref[211]=8'h66;
        sbox_ref[212]=8'h48; sbox_ref[213]=8'h03; sbox_ref[214]=8'hf6; sbox_ref[215]=8'h0e;
        sbox_ref[216]=8'h61; sbox_ref[217]=8'h35; sbox_ref[218]=8'h57; sbox_ref[219]=8'hb9;
        sbox_ref[220]=8'h86; sbox_ref[221]=8'hc1; sbox_ref[222]=8'h1d; sbox_ref[223]=8'h9e;
        // Row E
        sbox_ref[224]=8'he1; sbox_ref[225]=8'hf8; sbox_ref[226]=8'h98; sbox_ref[227]=8'h11;
        sbox_ref[228]=8'h69; sbox_ref[229]=8'hd9; sbox_ref[230]=8'h8e; sbox_ref[231]=8'h94;
        sbox_ref[232]=8'h9b; sbox_ref[233]=8'h1e; sbox_ref[234]=8'h87; sbox_ref[235]=8'he9;
        sbox_ref[236]=8'hce; sbox_ref[237]=8'h55; sbox_ref[238]=8'h28; sbox_ref[239]=8'hdf;
        // Row F
        sbox_ref[240]=8'h8c; sbox_ref[241]=8'ha1; sbox_ref[242]=8'h89; sbox_ref[243]=8'h0d;
        sbox_ref[244]=8'hbf; sbox_ref[245]=8'he6; sbox_ref[246]=8'h42; sbox_ref[247]=8'h68;
        sbox_ref[248]=8'h41; sbox_ref[249]=8'h99; sbox_ref[250]=8'h2d; sbox_ref[251]=8'h0f;
        sbox_ref[252]=8'hb0; sbox_ref[253]=8'h54; sbox_ref[254]=8'hbb; sbox_ref[255]=8'h16;
    end

    // --- Helper Function: RotWord (Behavioral) ---
    function [31:0] Check_RotWord;
        input [31:0] w;
        begin
            Check_RotWord = {w[23:0], w[31:24]};
        end
    endfunction

    // --- Helper Function: SubWord (Behavioral) ---
    function [31:0] Check_SubWord;
        input [31:0] w;
        begin
            Check_SubWord[31:24] = sbox_ref[w[31:24]];
            Check_SubWord[23:16] = sbox_ref[w[23:16]];
            Check_SubWord[15:8]  = sbox_ref[w[15:8]];
            Check_SubWord[7:0]   = sbox_ref[w[7:0]];
        end
    endfunction

    // --- Helper Function: Rcon Lookup (Behavioral) ---
    function [31:0] Check_Rcon;
        input [3:0] round;
        reg [7:0] rcon_byte;
        begin
            case(round)
                1: rcon_byte = 8'h01;
                2: rcon_byte = 8'h02;
                3: rcon_byte = 8'h04;
                4: rcon_byte = 8'h08;
                5: rcon_byte = 8'h10;
                6: rcon_byte = 8'h20;
                7: rcon_byte = 8'h40;
                8: rcon_byte = 8'h80;
                9: rcon_byte = 8'h1B;
                10:rcon_byte = 8'h36;
                default: rcon_byte = 8'h00;
            endcase
            Check_Rcon = {rcon_byte, 24'h000000};
        end
    endfunction

    // --- TASK: Calculate Next Key (The "Software" Engine) ---
    task calc_next_key_model;
        input [127:0] current_key;
        input [3:0]   round_num;
        output [127:0] next_key;
        
        reg [31:0] w0, w1, w2, w3;
        reg [31:0] g_func;
        begin
            // Split into words
            w0 = current_key[127:96];
            w1 = current_key[95:64];
            w2 = current_key[63:32];
            w3 = current_key[31:0];

            // Perform g-function on w3
            g_func = Check_RotWord(w3);
            g_func = Check_SubWord(g_func);
            g_func = g_func ^ Check_Rcon(round_num);

            // XOR chain
            w0 = w0 ^ g_func;
            w1 = w1 ^ w0;
            w2 = w2 ^ w1;
            w3 = w3 ^ w2;

            // Combine
            next_key = {w0, w1, w2, w3};
        end
    endtask

    // =========================================================================
    // 3. Test Sequence
    // =========================================================================
    
    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    reg [127:0] expected_key;
    integer i, k;

    initial begin
        // --- 1. Reset Setup (Active High) ---
        reset = 1;               // Start with Reset HIGH
        key_engine_start = 0;
        original_key = 0;
        #100;
        
        // --- 2. Release Reset ---
        reset = 0;               // Drop Reset to LOW to start
        #20;

        $display("---------------------------------------------------");
        $display("STARTING DYNAMIC SELF-CHECKING TEST (Active High Reset)");
        $display("---------------------------------------------------");

        // --- Loop 10 Times with Random Keys ---
        for (k = 0; k < 10; k = k + 1) begin
            
            // 1. Generate Random Key
            original_key[127:96] = $random;
            original_key[95:64]  = $random;
            original_key[63:32]  = $random;
            original_key[31:0]   = $random;
            
            // 2. Initialize Model Expectation
            expected_key = original_key;

            $display("\nTest Case %0d: Original Key = %h", k, original_key);

            // 3. Wait in PREP state
            key_engine_start = 0;
            #20; 

            // 4. Check PREP
            // Display PREP state status
            $display("PREP State: Expected = %h | Actual = %h", original_key, round_key);
            
            if (round_key !== original_key) begin
                $display("[FAIL] PREP State Mismatch!");
                $stop;
            end

            // 5. Trigger Start
            key_engine_start = 1'b1;
            
            // 6. Check Rounds 0 to 10 (2 phases per round in 10-sbox design)
            // Output mux: phase A → temp_key (current round key);
            //             phase B → next_key (the freshly-computed upcoming key,
            //                       made visible same cycle for encryption phase_b2).
            for (i = 0; i <= 10; i = i + 1) begin : round_check
                reg [127:0] next_expected;

                // Phase A: round_key should be the current round's key (temp_key)
                @(posedge clk);
                #1;
                $display("Round %0d Phase A: Expected = %h | Actual = %h", i, expected_key, round_key);
                if (round_key !== expected_key) begin
                    $display("[FAIL] Mismatch at Round %0d Phase A!", i);
                    $stop;
                end

                // Compute the upcoming round key (RK[i+1]) — the engine outputs this during phase B
                calc_next_key_model(expected_key, i+1, next_expected);

                // Phase B: round_key should be the NEXT round's key (next_key bypass)
                @(posedge clk);
                #1;
                $display("Round %0d Phase B: Expected = %h | Actual = %h", i, next_expected, round_key);
                if (round_key !== next_expected) begin
                    $display("[FAIL] Mismatch at Round %0d Phase B!", i);
                    $stop;
                end

                // Advance the model for the next round iteration
                expected_key = next_expected;
            end
            
            $display("[PASS] Test Case %0d passed.", k);
            
            // Reset Trigger for next loop
            key_engine_start = 0; 
            #20; 
        end

        $display("\n---------------------------------------------------");
        $display("ALL TESTS PASSED SUCCESSFULLY");
        $display("---------------------------------------------------");
        $finish;
    end

endmodule