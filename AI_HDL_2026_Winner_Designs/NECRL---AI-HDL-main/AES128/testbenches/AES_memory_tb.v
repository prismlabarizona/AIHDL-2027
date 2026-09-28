`timescale 1ns/1ps
module AES_memory_tb;

    reg clk = 0;
    reg [1:0] data_read_n = 2'b11;
    reg [1:0] data_write_n = 2'b11;
    reg [31:0] tb_data_in = 32'b0;
    reg [5:0] address = 6'b0;
    reg [127:0] ciphertext = 128'b0;
    reg done = 1'b0;
    reg fault = 1'b0;
    reg selftest_done = 1'b0;
    reg selftest_fail = 1'b0;
    wire [31:0] data_out;
    wire start;
    wire [127:0] encryption_engine_data;
    wire [127:0] original_key;
    wire reset_s;

    integer pass_count = 0;
    integer fail_count = 0;

    // instantiate DUT
    AES_memory dut (
        .clk(clk),
        .data_read_n(data_read_n),
        .data_write_n(data_write_n),
        .data_in(tb_data_in),
        .address(address),
        .ciphertext(ciphertext),
        .done(done),
        .fault(fault),
        .selftest_done(selftest_done),
        .selftest_fail(selftest_fail),
        .data_out(data_out),
        .start(start),
        .encryption_engine_data(encryption_engine_data),
        .original_key(original_key),
        .reset_s(reset_s)
    );

    // clock
    always #5 clk = ~clk;

    // helper tasks for 32-bit transfers (TinyQV: 10 = 32-bit)
    task write32(input [5:0] addr, input [31:0] data);
    begin
        @(posedge clk);
        #1;  // delay after posedge to avoid race with DUT's always block
        address = addr;
        tb_data_in = data;
        data_write_n = 2'b10;
        @(posedge clk);  // DUT samples here
        #1;
        data_write_n = 2'b11;
        #1;
    end
    endtask

    task check32(input [5:0] addr, input [31:0] expected);
    begin
        address = addr;
        data_read_n = 2'b10;
        #2;
        if (data_out !== expected) begin
            $display("  FAIL addr 0x%02h: got 0x%08h expected 0x%08h", addr, data_out, expected);
            fail_count = fail_count + 1;
        end else begin
            $display("  PASS addr 0x%02h => 0x%08h", addr, data_out);
            pass_count = pass_count + 1;
        end
        data_read_n = 2'b11;
        #1;
    end
    endtask

    task check_engine(input [127:0] expected128);
    begin
        #1;
        if (encryption_engine_data !== expected128) begin
            $display("  ENGINE FAIL: got 0x%032h expected 0x%032h", encryption_engine_data, expected128);
            fail_count = fail_count + 1;
        end else begin
            $display("  ENGINE PASS => 0x%032h", encryption_engine_data);
            pass_count = pass_count + 1;
        end
    end
    endtask

    task check_sig(input got, input expected, input [8*40:1] name);
    begin
        if (got !== expected) begin
            $display("  FAIL %0s: got %b expected %b", name, got, expected);
            fail_count = fail_count + 1;
        end else begin
            $display("  PASS %0s => %b", name, got);
            pass_count = pass_count + 1;
        end
    end
    endtask

    // Key is write-only on the bus (Rank 1 fix): reads of 0x02-0x05 return 0.
    // Verify key-related security properties (key_lock, key persistence)
    // against the internal original_key wire instead of bus readback.
    task check_key(input [127:0] expected);
    begin
        #1;
        if (original_key !== expected) begin
            $display("  FAIL original_key: got 0x%032h expected 0x%032h", original_key, expected);
            fail_count = fail_count + 1;
        end else begin
            $display("  PASS original_key => 0x%032h", original_key);
            pass_count = pass_count + 1;
        end
    end
    endtask

    task engine_done(input [127:0] ct);
    begin
        ciphertext = ct;
        #1;
        done = 1'b1;
        @(posedge clk);
        #1;
        done = 1'b0;
        @(posedge clk);
        #1;
    end
    endtask

    task do_reset;
    begin
        write32(6'h00, 32'h00000002);
        @(posedge clk); #5;
    end
    endtask

    initial begin
        $dumpfile("aes_memory_tb.vcd");
        $dumpvars(0, AES_memory_tb);
        #20;

        // Initial reset to clear all state
        do_reset;

        // =========================================================
        // TEST 1: Basic key/data write, read, key_lock, start, done
        // =========================================================
        $display("\n=== TEST 1: Basic write/read, key_lock, start/done ===");

        write32(6'h02, 32'hAAAAAAAA);
        write32(6'h03, 32'hBBBBBBBB);
        write32(6'h04, 32'hCCCCCCCC);
        write32(6'h05, 32'hDDDDDDDD);
        // Bus reads of key addresses must return 0 (write-only key).
        check32(6'h02, 32'h00000000);
        check32(6'h03, 32'h00000000);
        check32(6'h04, 32'h00000000);
        check32(6'h05, 32'h00000000);
        // But the key must have actually landed in the internal register.
        check_key({32'hDDDDDDDD, 32'hCCCCCCCC, 32'hBBBBBBBB, 32'hAAAAAAAA});

        write32(6'h06, 32'h0F0F0F0F);
        write32(6'h07, 32'hF0F0F0F0);
        write32(6'h08, 32'h12345678);
        write32(6'h09, 32'h87654321);
        check32(6'h06, 32'h0F0F0F0F);
        check32(6'h07, 32'hF0F0F0F0);
        check32(6'h08, 32'h12345678);
        check32(6'h09, 32'h87654321);

        // Manual start
        write32(6'h00, 32'h00000001);
        check_sig(start, 1'b1, "start_asserted");

        // Simulate done — verify auto-clear
        engine_done({32'hA1A1A1A1, 32'hB2B2B2B2, 32'hC3C3C3C3, 32'hD4D4D4D4});
        check_sig(start, 1'b0, "start_auto_cleared");

        check32(6'h0A, 32'hD4D4D4D4);
        check32(6'h0B, 32'hC3C3C3C3);
        check32(6'h0C, 32'hB2B2B2B2);
        check32(6'h0D, 32'hA1A1A1A1);

        // Key lock: attempted overwrite must be ignored. Bus readback is 0
        // regardless, so verify via original_key that the key wasn't mutated.
        write32(6'h00, 32'h00000004);
        write32(6'h02, 32'hDEAD0000);
        check32(6'h02, 32'h00000000);
        check_key({32'hDDDDDDDD, 32'hCCCCCCCC, 32'hBBBBBBBB, 32'hAAAAAAAA});

        do_reset;

        // =========================================================
        // TEST 2: Auto-start on last direct plaintext write (0x09)
        // =========================================================
        $display("\n=== TEST 2: Auto-start via direct address 0x09 ===");

        write32(6'h00, 32'h00000008); // auto_start = 1
        check_sig(start, 1'b0, "start_before_writes");

        write32(6'h06, 32'h11111111);
        check_sig(start, 1'b0, "after_0x06");
        write32(6'h07, 32'h22222222);
        check_sig(start, 1'b0, "after_0x07");
        write32(6'h08, 32'h33333333);
        check_sig(start, 1'b0, "after_0x08");
        write32(6'h09, 32'h44444444);
        check_sig(start, 1'b1, "after_0x09_auto");

        engine_done({32'h55555555, 32'h66666666, 32'h77777777, 32'h88888888});
        check_sig(start, 1'b0, "done_clears_start");

        check32(6'h0A, 32'h88888888);
        check32(6'h0B, 32'h77777777);
        check32(6'h0C, 32'h66666666);
        check32(6'h0D, 32'h55555555);

        do_reset;

        // =========================================================
        // TEST 3: Double-buffering (ping-pong) — write next block
        //         while engine encrypts current block
        // =========================================================
        $display("\n=== TEST 3: Double-buffering (ping-pong) ===");

        write32(6'h00, 32'h00000008); // auto_start = 1

        // --- Block 1: write via direct addresses, auto-start on 0x09 ---
        $display("  Block 1: write + auto-start");
        write32(6'h06, 32'h01010101);
        write32(6'h07, 32'h02020202);
        write32(6'h08, 32'h03030303);
        write32(6'h09, 32'h04040404); // auto-start, banks swap
        check_sig(start, 1'b1, "blk1_started");
        check_engine({32'h04040404, 32'h03030303, 32'h02020202, 32'h01010101});

        // Write Block 2 into the now-idle bank while Block 1 encrypts
        $display("  Block 2: writing while Block 1 encrypts...");
        write32(6'h06, 32'hA0A0A0A0);
        write32(6'h07, 32'hB0B0B0B0);
        write32(6'h08, 32'hC0C0C0C0);
        // Hold off 0x09 write — engine not done yet

        // Block 1 engine finishes
        engine_done({32'hC1C1C1C1, 32'hD1D1D1D1, 32'hE1E1E1E1, 32'hF1F1F1F1});
        check_sig(start, 1'b0, "blk1_done");

        // Read Block 1 ciphertext via direct addresses
        $display("  Read Block 1 ciphertext via 0x0A-0x0D");
        check32(6'h0A, 32'hF1F1F1F1);
        check32(6'h0B, 32'hE1E1E1E1);
        check32(6'h0C, 32'hD1D1D1D1);
        check32(6'h0D, 32'hC1C1C1C1);

        // Now write 4th word of Block 2 → auto-start, banks swap again
        write32(6'h09, 32'hD0D0D0D0);
        check_sig(start, 1'b1, "blk2_started");
        check_engine({32'hD0D0D0D0, 32'hC0C0C0C0, 32'hB0B0B0B0, 32'hA0A0A0A0});

        // Block 2 engine finishes
        engine_done({32'hC2C2C2C2, 32'hD2D2D2D2, 32'hE2E2E2E2, 32'hF2F2F2F2});
        check_sig(start, 1'b0, "blk2_done");

        // Read Block 2 ciphertext via direct addresses
        $display("  Read Block 2 ciphertext via 0x0A-0x0D");
        check32(6'h0A, 32'hF2F2F2F2);
        check32(6'h0B, 32'hE2E2E2E2);
        check32(6'h0C, 32'hD2D2D2D2);
        check32(6'h0D, 32'hC2C2C2C2);

        // =========================================================
        // TEST 4: Key reuse across multiple encryptions
        // =========================================================
        $display("\n=== TEST 4: Key reuse (key persists across encryptions) ===");

        do_reset;

        // Write key once
        write32(6'h02, 32'h2B7E1516);
        write32(6'h03, 32'h28AED2A6);
        write32(6'h04, 32'hABF71588);
        write32(6'h05, 32'h09CF4F3C);

        // Set key_lock + auto_start
        write32(6'h00, 32'h0000000C); // bits 2+3

        // Encrypt block A via direct addresses
        write32(6'h06, 32'hAAAAAAAA);
        write32(6'h07, 32'hBBBBBBBB);
        write32(6'h08, 32'hCCCCCCCC);
        write32(6'h09, 32'hDDDDDDDD); // auto-start
        check_sig(start, 1'b1, "key_reuse_blkA_start");
        engine_done({32'h11111111, 32'h22222222, 32'h33333333, 32'h44444444});

        // Verify key is still loaded internally (bus reads return 0 by design).
        check32(6'h02, 32'h00000000);
        check32(6'h03, 32'h00000000);
        check32(6'h04, 32'h00000000);
        check32(6'h05, 32'h00000000);
        check_key({32'h09CF4F3C, 32'hABF71588, 32'h28AED2A6, 32'h2B7E1516});

        // Encrypt block B (no key rewrite needed)
        write32(6'h06, 32'hEEEEEEEE);
        write32(6'h07, 32'hFFFFFFFF);
        write32(6'h08, 32'h00000000);
        write32(6'h09, 32'h11111111); // auto-start
        check_sig(start, 1'b1, "key_reuse_blkB_start");

        // Key still locked (verify internally — bus reads return 0).
        check32(6'h02, 32'h00000000);
        check_key({32'h09CF4F3C, 32'hABF71588, 32'h28AED2A6, 32'h2B7E1516});

        engine_done({32'h55555555, 32'h66666666, 32'h77777777, 32'h88888888});

        // =========================================================
        // TEST 5: Soft reset interlock (Rank 5 fix)
        //
        // Soft reset (control_reg bit1) must be ignored while the engine
        // is busy (control_reg[0] == 1). This prevents DoS key-wipes and
        // mid-expansion key corruption. See DP3_submission/security_report.pdf.
        // =========================================================
        $display("\n=== TEST 5: Soft reset interlock while engine busy ===");

        do_reset;

        // Load a known key and plaintext.
        write32(6'h02, 32'hDEADBEEF);
        write32(6'h03, 32'hCAFEBABE);
        write32(6'h04, 32'h12345678);
        write32(6'h05, 32'h9ABCDEF0);
        write32(6'h06, 32'h11111111);
        write32(6'h07, 32'h22222222);
        write32(6'h08, 32'h33333333);
        write32(6'h09, 32'h44444444);
        check_key({32'h9ABCDEF0, 32'h12345678, 32'hCAFEBABE, 32'hDEADBEEF});

        // Start encryption (engine now busy).
        write32(6'h00, 32'h00000001);
        check_sig(start, 1'b1, "t5_start_asserted");

        // Attempt soft reset while busy — must be DROPPED.
        write32(6'h00, 32'h00000002);
        check_sig(reset_s, 1'b0, "t5_reset_suppressed_while_busy");
        check_sig(start, 1'b1, "t5_start_still_asserted");
        // Key must be intact (no mid-expansion wipe).
        check_key({32'h9ABCDEF0, 32'h12345678, 32'hCAFEBABE, 32'hDEADBEEF});

        // Combined start+reset write while busy: reset bit stripped, other
        // bits still applied (control_reg gets data_in & ~0x2).
        write32(6'h00, 32'h0000000E); // bits 1+2+3, bit1 must be masked
        check_sig(reset_s, 1'b0, "t5_reset_bit_masked_in_combined_write");
        check_key({32'h9ABCDEF0, 32'h12345678, 32'hCAFEBABE, 32'hDEADBEEF});

        // Finish the encryption — engine returns to idle.
        engine_done({32'hAAAAAAAA, 32'hBBBBBBBB, 32'hCCCCCCCC, 32'hDDDDDDDD});
        check_sig(start, 1'b0, "t5_idle_after_done");

        // Soft reset now permitted (engine idle).
        write32(6'h00, 32'h00000002);
        check_sig(reset_s, 1'b1, "t5_reset_honored_when_idle");
        @(posedge clk); #1;
        check_key(128'b0);

        // =========================================================
        // TEST 6: fault bit visible in status register (Rank 7)
        // =========================================================
        $display("\n=== TEST 6: fault exposed in status reg bit 1 ===");

        // Baseline: fault=0, done=0 -> status == 0
        fault = 1'b0;
        done  = 1'b0;
        check32(6'h01, 32'h00000000);

        // Raise fault alone: bit1 set, bit0 clear
        fault = 1'b1;
        check32(6'h01, 32'h00000002);

        // Drop fault: bit1 clears again
        fault = 1'b0;
        check32(6'h01, 32'h00000000);

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

endmodule
