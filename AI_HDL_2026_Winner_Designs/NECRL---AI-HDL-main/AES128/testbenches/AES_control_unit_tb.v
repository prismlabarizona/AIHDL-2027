`timescale 1ns/1ps
module AES_control_unit_tb;

    reg clk = 0;
    reg start = 0;
    reg reset_n = 0;
    reg reset_s = 0;
    integer i;
    integer found;
    integer runs;
    integer j;
    integer saw_twenty_one;

    wire done;
    wire reset;
    wire fault;
    wire stall;
    wire [4:0] encryption_engine_count;
    wire key_engine_start;

    // DUT
    AES_control_unit dut (
        .clk(clk),
        .start(start),
        .reset_n(reset_n),
        .reset_s(reset_s),
        .done(done),
        .reset(reset),
        .fault(fault),
        .stall(stall),
        .encryption_engine_count(encryption_engine_count),
        .key_engine_start(key_engine_start)
    );

    // clock
    always #5 clk = ~clk;

    task assert_eq(input [0:0] cond, input [8*64-1:0] msg);
    begin
        if (!cond) begin
            $display("ASSERT FAIL: %s", msg);
            $fatal(1);
        end else begin
            $display("ASSERT PASS: %s", msg);
        end
    end
    endtask

    initial begin
        // reset pulse via reset_n
        reset_n = 1'b1;
        #20;
        reset_n = 1'b0; // release reset
        #20;

        // assert that after reset the unit is idle
        assert_eq((done === 1'b0), "done is 0 after reset");
        assert_eq((encryption_engine_count === 5'b00000), "enc count is 0 after reset");
        assert_eq((key_engine_start === 1'b0), "key start is 0 after reset");

        // pulse start for two cycles to ensure sampling
        start = 1'b1;
        @(posedge clk);
        @(posedge clk);
        start = 1'b0;

        // after starting, encryption counter should become non-zero within a few cycles
        found = 0;
        for (i = 0; i < 10; i = i + 1) begin
            @(posedge clk);
            if (encryption_engine_count !== 5'b00000) begin
                found = 1;
                i = 10; // break
            end
        end
        if (!found) begin
            $display("ASSERT FAIL: starts did not assert within 10 cycles");
            $fatal(1);
        end else begin
            $display("ASSERT PASS: starts asserted within 10 cycles");
        end

        // wait for done; ensure the counter reached 11 at some point beforehand
        saw_twenty_one = 0;
        while (done == 1'b0) begin
            @(posedge clk);
            if (encryption_engine_count === 5'd21) saw_twenty_one = 1;
        end
        $display("%0t: done asserted", $time);
        // when done the counter output should be 0 (not counting)
        assert_eq((encryption_engine_count === 5'b00000), "enc count is 0 when done asserted");
        assert_eq((key_engine_start === 1'b0), "key start deasserted at done");
        assert_eq((done === 1'b1), "done is 1 at completion");
        // ensure we observed the counter reach 21 prior to done
        assert_eq((saw_twenty_one === 1), "counter reached 21 before done");

        // test reset via reset_s
        reset_s = 1'b1;
        @(posedge clk);
        reset_s = 1'b0;
        @(posedge clk);

        // after reset, outputs should be cleared
        assert_eq((done === 1'b0), "done cleared after reset");
        assert_eq((encryption_engine_count === 5'b00000), "enc count cleared after reset");
        assert_eq((key_engine_start === 1'b0), "key start cleared after reset");

        // --- Corner case 1: assert start again while counting ---
        // start a new run (hold for two cycles)
        start = 1'b1;
        @(posedge clk);
        @(posedge clk);
        start = 1'b0;
        // wait for starts asserted
        found = 0; for (i = 0; i < 10; i = i + 1) begin @(posedge clk); if (encryption_engine_count!==5'b00000) begin found=1; i=10; end end
        if (!found) begin $display("ASSERT FAIL: start did not assert for corner1"); $fatal(1); end
        // assert start again while counting
        start = 1'b1; @(posedge clk); start = 1'b0;
        // ensure we still reach done
        wait (done == 1'b1);
        assert_eq((done === 1'b1), "done after repeated start during counting");

        // --- Corner case 2: fresh start pulse in DONE triggers new encryption ---
        @(posedge clk); @(posedge clk);
        assert_eq((done === 1'b1), "done remains 1 (sticky DONE state)");
        start = 1'b1; @(posedge clk); start = 1'b0;
        @(posedge clk);
        assert_eq((done === 1'b0), "rising edge of start restarts from DONE");

        // now clear via reset (no-op placeholder)

        // --- Corner case 3: reset asserted during counting clears and allows restart ---
        // issue reset via reset_s to clear to idle
        reset_s = 1'b1; @(posedge clk); reset_s = 1'b0; @(posedge clk);
        // start counting
        start = 1'b1; @(posedge clk); start = 1'b0;
        // wait one cycle of counting then assert reset
        @(posedge clk);
        reset_s = 1'b1; @(posedge clk); reset_s = 1'b0; @(posedge clk);
        // check cleared
        assert_eq((done === 1'b0), "done cleared by reset during counting");
        assert_eq((encryption_engine_count === 5'b00000), "enc count cleared by reset during counting");

        // --- Corner case 4: rapid single-cycle start pulses (multiple runs) ---
        runs = 3;
        for (i = 0; i < runs; i = i + 1) begin
            // short pulse (two cycles) to ensure reliable detection
            start = 1'b1;
            @(posedge clk);
            @(posedge clk);
            start = 1'b0;
            // ensure starts asserted within window
            found = 0;
            for (j = 0; j < 10; j = j + 1) begin
                @(posedge clk);
                if (encryption_engine_count !== 5'b00000) begin
                    found = 1;
                    j = 10;
                end
            end
            if (!found) begin
                $display("ASSERT FAIL: rapid start run %0d did not assert", i);
                $fatal(1);
            end
            // wait for done and then reset to prepare next run
            wait (done == 1'b1);
            reset_s = 1'b1; @(posedge clk); reset_s = 1'b0; @(posedge clk);
        end

        // ================================================================
        // Rank 2 security tests: FSM and round-counter integrity protection
        // ================================================================

        // --- R2-1: fault=0 on happy path ---
        reset_n = 1'b1; @(posedge clk); reset_n = 1'b0; @(posedge clk);
        assert_eq((fault === 1'b0), "fault clear after hard reset");
        start = 1'b1; @(posedge clk); @(posedge clk); start = 1'b0;
        wait (done == 1'b1);
        assert_eq((fault === 1'b0), "fault stays 0 on happy path");

        // --- R2-2: count glitch (breaks count+shadow==22) -> FAULT ---
        reset_n = 1'b1; @(posedge clk); reset_n = 1'b0; @(posedge clk);
        start = 1'b1; @(posedge clk); @(posedge clk); start = 1'b0;
        repeat (6) @(posedge clk);          // mid-run
        force dut.count = dut.count ^ 5'b00100;
        @(posedge clk);
        release dut.count;
        @(posedge clk);
        assert_eq((fault === 1'b1), "count glitch latched FAULT");
        assert_eq((done === 1'b0), "done stays 0 after count glitch");
        assert_eq((encryption_engine_count === 5'd0), "count output zeroed in FAULT");
        assert_eq((key_engine_start === 1'b0), "key_engine_start dropped in FAULT");

        // --- R2-3: FAULT is sticky across soft reset ---
        reset_s = 1'b1; @(posedge clk); reset_s = 1'b0; @(posedge clk); @(posedge clk);
        assert_eq((fault === 1'b1), "soft reset cannot clear FAULT");
        assert_eq((done === 1'b0), "done still 0 after soft reset in FAULT");

        // --- R2-4: hard reset clears FAULT ---
        reset_n = 1'b1; @(posedge clk); reset_n = 1'b0; @(posedge clk);
        assert_eq((fault === 1'b0), "hard reset clears FAULT");

        // --- R2-5: illegal one-hot FSM code -> FAULT ---
        start = 1'b1; @(posedge clk); @(posedge clk); start = 1'b0;
        repeat (4) @(posedge clk);
        force dut.state = 4'b0011;          // 2-hot, illegal
        @(posedge clk);
        release dut.state;
        @(posedge clk);
        assert_eq((fault === 1'b1), "illegal one-hot state caught");

        // --- R2-6: start after FAULT is ignored (sticky) ---
        start = 1'b1; @(posedge clk); @(posedge clk); start = 1'b0;
        @(posedge clk);
        assert_eq((fault === 1'b1), "start ignored while in FAULT");
        assert_eq((done === 1'b0), "done stays 0 when start pulsed in FAULT");

        // --- R2-7: shadow counter glitch alone also trips FAULT ---
        reset_n = 1'b1; @(posedge clk); reset_n = 1'b0; @(posedge clk);
        start = 1'b1; @(posedge clk); @(posedge clk); start = 1'b0;
        repeat (5) @(posedge clk);
        force dut.count_shadow = dut.count_shadow ^ 5'b01000;
        @(posedge clk);
        release dut.count_shadow;
        @(posedge clk);
        assert_eq((fault === 1'b1), "shadow-counter glitch latched FAULT");

        $display("AES_control_unit_tb: ALL ASSERTS PASSED");
        #10;
        $finish;
    end

endmodule
