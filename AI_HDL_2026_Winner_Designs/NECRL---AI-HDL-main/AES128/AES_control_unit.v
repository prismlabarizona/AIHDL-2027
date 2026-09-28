module AES_control_unit (
    input  clk,
    input  start,
    input  reset_n,
    input  reset_s,

    output reg  done,
    output wire reset,
    output wire fault,
    output wire stall,

    output [4:0] encryption_engine_count,
    output reg   key_engine_start
);

    // reset wire is OR of the two sources (unchanged, consumed externally)
    assign reset = reset_n || reset_s;

    // One-hot FSM with explicit FAULT. Any single bit flip turns a legal
    // code into a 0-hot or 2-hot value, caught by state_ok below.
    localparam [3:0]
        IDLE  = 4'b0001,
        RUN   = 4'b0010,
        DONE  = 4'b0100,
        FAULT = 4'b1000;

    reg [3:0] state;
    reg [4:0] count;
    reg [4:0] count_shadow;   // invariant: count + count_shadow == 31

    // Rank 6: LFSR-based random stall for DPA countermeasure
    reg [7:0]  lfsr;          // 8-bit LFSR (x^8+x^6+x^5+x^4+1)
    reg [3:0]  stall_count;   // total stalls this encryption run (max 1, DP4 budget)
    reg        fault_latch;   // sticky fault — survives soft reset
    reg        start_d;       // delayed start for rising-edge detection in DONE

    // Integrity detectors
    wire state_ok       = (state == IDLE)  || (state == RUN)
                       || (state == DONE) || (state == FAULT);
    wire [5:0] cs_sum   = {1'b0, count} + {1'b0, count_shadow};
    wire count_ok       = (cs_sum == 6'd31);
    wire integrity_fail = !state_ok || !count_ok;

    assign fault = fault_latch || (state == FAULT);

    // Expose counter directly. count is naturally 0 in IDLE/DONE/FAULT (FSM resets it
    // in those states); engine ignores nonzero count during stall via its own !stall
    // guard. Removing the (state == RUN && !stall) mux breaks the state[1] critical
    // path through engine combinational logic. Defense-in-depth preserved by FSM,
    // not by combinational gating.
    assign encryption_engine_count = count;

    // Stall eligible counts 2..28 (rounds 1..9 phase A/B1/B2);
    // counts 29..30 are final round phase A/B and must not stall (≤32 cycle guarantee)
    assign stall = (state == RUN) && (count >= 5'd2) && (count <= 5'd28)
                && (stall_count < 4'd1)   // budget: ≤ 1 stall per encryption (DP4 DPA tradeoff)
                && !integrity_fail
                && (lfsr[1:0] == 2'b00);

    // ---------------------------------------------------------------
    // Always block 1: Main FSM (dual async reset, constant-only resets)
    // ---------------------------------------------------------------
    always @(posedge clk or posedge reset_n or posedge reset_s) begin
        if (reset_n) begin
            state            <= IDLE;
            count            <= 5'd0;
            count_shadow     <= 5'd31;
            done             <= 1'b0;
            key_engine_start <= 1'b0;
            stall_count      <= 4'd0;
            start_d          <= 1'b0;
        end else if (reset_s) begin
            state            <= IDLE;
            count            <= 5'd0;
            count_shadow     <= 5'd31;
            done             <= 1'b0;
            key_engine_start <= 1'b0;
            stall_count      <= 4'd0;
            start_d          <= 1'b0;
        end else begin
            start_d <= start;
            if (fault_latch || integrity_fail) begin
                state            <= FAULT;
                count            <= 5'd0;
                count_shadow     <= 5'd0;
                done             <= 1'b0;
                key_engine_start <= 1'b0;
                stall_count      <= 4'd0;
            end else if (state == FAULT) begin
                // Sticky — only reset_n can clear this.
                state            <= FAULT;
                count            <= 5'd0;
                count_shadow     <= 5'd0;
                done             <= 1'b0;
                key_engine_start <= 1'b0;
                stall_count      <= 4'd0;
            end else begin
                case (state)
                    IDLE: begin
                        done             <= 1'b0;
                        key_engine_start <= 1'b0;
                        count            <= 5'd0;
                        count_shadow     <= 5'd31;
                        stall_count      <= 4'd0;

                        if (start && !start_d) begin
                            state            <= RUN;
                            count            <= 5'd1;       // skip idle entry, jump to init cycle
                            count_shadow     <= 5'd30;      // invariant: count + count_shadow == 31
                            key_engine_start <= 1'b1;
                            stall_count      <= 4'd0;
                        end
                    end

                    RUN: begin
                        key_engine_start <= 1'b0;
                        done             <= 1'b0;

                        if (stall) begin
                            // Rank 6: stall cycle — freeze count, increment stall_count
                            stall_count <= stall_count + 1'b1;
                        end else if (count == 5'd31) begin
                            if (count_shadow == 5'd0) begin
                                state        <= DONE;
                                count        <= 5'd0;
                                count_shadow <= 5'd31;
                            end else begin
                                state        <= FAULT;
                                count        <= 5'd0;
                                count_shadow <= 5'd0;
                            end
                        end else if (count == 5'd30) begin
                            count        <= 5'd31;
                            count_shadow <= 5'd0;
                        end else if (count <= 5'd29) begin
                            count        <= count + 1'b1;
                            count_shadow <= count_shadow - 1'b1;
                        end else begin
                            state        <= FAULT;
                            count        <= 5'd0;
                            count_shadow <= 5'd0;
                        end
                    end

                    DONE: begin
                        done             <= 1'b1;
                        key_engine_start <= 1'b0;
                        count            <= 5'd0;
                        count_shadow     <= 5'd31;

                        if (start && !start_d) begin
                            state            <= RUN;
                            count            <= 5'd1;       // skip idle entry, jump to init cycle
                            count_shadow     <= 5'd30;      // invariant: count + count_shadow == 31
                            done             <= 1'b0;
                            key_engine_start <= 1'b1;
                            stall_count      <= 4'd0;
                        end
                    end

                    default: begin
                        state            <= FAULT;
                        count            <= 5'd0;
                        count_shadow     <= 5'd0;
                        done             <= 1'b0;
                        key_engine_start <= 1'b0;
                    end
                endcase
            end
        end
    end

    // ---------------------------------------------------------------
    // Always block 2: LFSR free-running (hard-reset only)
    // ---------------------------------------------------------------
    always @(posedge clk or posedge reset_n) begin
        if (reset_n)
            lfsr <= 8'hAC;
        else
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
    end

    // ---------------------------------------------------------------
    // Always block 3: fault_latch — sticky, survives soft reset
    // ---------------------------------------------------------------
    always @(posedge clk or posedge reset_n) begin
        if (reset_n)
            fault_latch <= 1'b0;
        else if (integrity_fail || state == FAULT)
            fault_latch <= 1'b1;
    end

endmodule
