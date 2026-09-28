/*
 * Enhanced SPI Master Peripheral for TinyQV
 * ============================================
 * New features vs. simple version:
 *   1. Full SPI modes 0-3 (CPOL + CPHA)        — 2 config bits
 *   2. MISO receive shift register              — full duplex
 *   3. Configurable word length (4–8 bits)      — 3 config bits
 *   4. LSB-first / MSB-first selectable         — 1 config bit
 *   5. Manual CS control (multi-byte bursts)    — 1 config bit
 *   6. Transfer-complete IRQ flag               — 1 status bit, write-1-clear
 *
 * Register Map:
 *   Addr 0  TX Data   (W) / RX Data (R)  — write starts transfer if not busy
 *   Addr 1  Status    (R/W) [0]=busy  [1]=irq (write 1 to clear irq)
 *   Addr 2  Clock Div (R/W) 6-bit value; SCLK = sys_clk / (2*(div+1))
 *   Addr 3  Config    (R/W) [0]=CPOL  [1]=CPHA  [2]=LSB_first
 *                           [3]=manual_cs  [6:4]=word_len-1 (0→1-bit…7→8-bit)
 *   Addr 4  CS Ctrl   (W)   [0]=cs_assert  (only active when manual_cs=1)
 *
 * PPA decisions:
 *   - busy/cs_n are combinatorial wires            → 0 extra FFs
 *   - CPOL is XOR'd at the output wire             → 0 extra mux in state machine
 *   - CPHA reuses spi_clk_r initial value          → 0 extra state bits
 *   - LSB-first reversal only at load time         → 0 per-cycle mux cost
 *   - IRQ reuses bit_cnt==1 terminal condition     → no extra comparator
 *   - word_len stored as terminal count, loaded once per transfer
 *   - div counter is 6-bit (not 8-bit)             → 4 fewer FFs
 *   - wire-OR data_out                             → shallower mux cone
 */

`default_nettype none

module tqvp_spi_master (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] ui_in,        // ui_in[0] = MISO from external SPI device
    output wire [7:0] uo_out,       // [0]=SCLK [1]=MOSI [2]=CS_n [3]=IRQ
    input  wire [3:0] address,
    input  wire       data_write,
    input  wire [7:0] data_in,
    output wire [7:0] data_out
);

    // =========================================================================
    // Configuration (packed into one FF bank to help the synthesiser)
    // =========================================================================
    reg        cfg_cpol;
    reg        cfg_cpha;
    reg        cfg_lsb;
    reg        cfg_mcs;        // Manual CS enable
    reg [2:0]  cfg_wlen;       // Word length - 1  (0→1-bit … 7→8-bit; use 7 for 8-bit)

    // =========================================================================
    // Operational registers
    // =========================================================================
    reg [7:0]  tx_shift;
    reg [7:0]  rx_shift;
    reg [7:0]  rx_hold;        // Latched complete RX word
    reg [5:0]  clk_div;
    reg [5:0]  div_cnt;
    reg [3:0]  bit_cnt;        // Counts remaining bits (0 = idle)
    reg        spi_clk_r;      // Internal clock state (CPOL applied at output)
    reg        cs_force;       // Manual CS FF
    reg        irq;            // Transfer-complete flag

    // =========================================================================
    // Combinatorial signals
    // =========================================================================
    wire busy     = (bit_cnt != 4'h0);
    wire miso     = ui_in[0];           // MISO sourced from ui_in[0]
    wire cs_n     = cfg_mcs ? ~cs_force : ~busy;
    wire sclk_out = spi_clk_r ^ cfg_cpol;  // Free CPOL inversion at output

    // LSB-first byte reversal — only evaluated at load time
    wire [7:0] tx_load = cfg_lsb
        ? {data_in[0], data_in[1], data_in[2], data_in[3],
           data_in[4], data_in[5], data_in[6], data_in[7]}
        : data_in;

    // =========================================================================
    // State machine
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            tx_shift   <= 8'h00;
            rx_shift   <= 8'h00;
            rx_hold    <= 8'h00;
            clk_div    <= 6'd3;
            div_cnt    <= 6'h00;
            bit_cnt    <= 4'h0;
            spi_clk_r  <= 1'b0;
            cs_force   <= 1'b0;
            irq        <= 1'b0;
            cfg_cpol   <= 1'b0;
            cfg_cpha   <= 1'b0;
            cfg_lsb    <= 1'b0;
            cfg_mcs    <= 1'b0;
            cfg_wlen   <= 3'd7;   // Default 8-bit
        end else begin

            // ------------------------------------------------------------------
            // CPU writes
            // ------------------------------------------------------------------
            if (data_write) begin
                case (address)
                    4'h1: if (data_in[1]) irq <= 1'b0;  // Write-1-clear IRQ
                    4'h2: clk_div <= data_in[5:0];
                    4'h3: {cfg_wlen, cfg_mcs, cfg_lsb, cfg_cpha, cfg_cpol}
                              <= {data_in[6:4], data_in[3:0]};
                    4'h4: cs_force <= data_in[0];
                    default: ;
                endcase
            end

            // Start transfer (addr 0 write, not busy)
            if (data_write && address == 4'h0 && !busy) begin
                tx_shift  <= tx_load;
                bit_cnt   <= {1'b0, cfg_wlen} + 4'h1;  // 1..8
                div_cnt   <= 6'h00;
                // CPHA=1: begin with clock high so first active edge is falling
                spi_clk_r <= cfg_cpha;
                irq       <= 1'b0;

            end else if (busy) begin
                if (div_cnt < clk_div) begin
                    div_cnt <= div_cnt + 1'b1;
                end else begin
                    div_cnt   <= 6'h00;
                    spi_clk_r <= ~spi_clk_r;

                    // -----------------------------------------------------------
                    // CPHA=0: sample on rising (spi_clk_r==0→1), shift on fall
                    // CPHA=1: sample on falling (spi_clk_r==1→0), shift on rise
                    // In both cases:
                    //   sample when spi_clk_r == cfg_cpha  (first half-period edge)
                    //   shift  when spi_clk_r != cfg_cpha  (second half-period edge)
                    // -----------------------------------------------------------
                    if (spi_clk_r == cfg_cpha) begin
                        // Sample edge — capture MISO into RX shift register
                        rx_shift <= {rx_shift[6:0], miso};
                    end else begin
                        // Shift edge — advance TX, decrement bit counter
                        tx_shift <= {tx_shift[6:0], 1'b0};
                        bit_cnt  <= bit_cnt - 1'b1;

                        if (bit_cnt == 4'h1) begin
                            // All 8 samples are already in rx_shift.
                            // Do NOT re-sample miso here (this is the shift
                            // edge, not a sample edge) — doing so would drop
                            // rx_shift[7] and produce a left-rotate-by-1 error.
                            rx_hold <= cfg_lsb
                                ? {rx_shift[0], rx_shift[1], rx_shift[2], rx_shift[3],
                                   rx_shift[4], rx_shift[5], rx_shift[6], rx_shift[7]}
                                : rx_shift;
                            irq <= 1'b1;
                        end
                    end
                end
            end

        end
    end

    // =========================================================================
    // CPU read interface — wire-OR avoids cascaded ternary mux chain
    // =========================================================================
    assign data_out =
        ({8{address == 4'h0}} & rx_hold)
      | ({8{address == 4'h1}} & {6'b0, irq, busy})
      | ({8{address == 4'h2}} & {2'b0, clk_div})
      | ({8{address == 4'h3}} & {1'b0, cfg_wlen, cfg_mcs, cfg_lsb, cfg_cpha, cfg_cpol});

    // =========================================================================
    // Output mapping
    // =========================================================================
    assign uo_out = {4'b0, irq, cs_n, tx_shift[7], sclk_out};

    // Suppress unused-input warnings for ui_in[7:1]
    wire _unused_ui = &{ui_in[7:1]};

endmodule
