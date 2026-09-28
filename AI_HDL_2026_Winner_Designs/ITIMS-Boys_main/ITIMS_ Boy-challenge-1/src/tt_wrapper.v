/*
 * Copyright (c) 2025 Michael Bell
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

/** TinyQV peripheral test using SPI */
module tt_um_tqv_peripheral_harness (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // SPI access to registers
  wire [3:0] address;
  wire [7:0] data_in;  // Data in to peripheral
  wire [7:0] data_out; // Data out from peripheral
  wire data_valid;

  // Peripherals get synchronized ui_in.
  reg [7:0] ui_in_sync;
  synchronizer #(.STAGES(2), .WIDTH(8)) synchronizer_ui_in_inst (.clk(clk), .data_in(ui_in), .data_out(ui_in_sync));

  // Register reset as in TinyQV
  /* verilator lint_off SYNCASYNCNET */
  reg rst_reg_n;
  /* verilator lint_on SYNCASYNCNET */
  always @(negedge clk) rst_reg_n <= rst_n;

  // The peripheral under test.
  // **** Change the module name from tqvp_example to match your peripheral. ****
  tqvp_spi_master user_peripheral(
    .clk(clk),
    .rst_n(rst_reg_n),
    .ui_in(ui_in_sync),
    .uo_out(uo_out),
    .address(address),
    .data_write(data_valid),
    .data_in(data_in),
    .data_out(data_out)
  );

  // SPI interface
  wire spi_cs_n;
  wire spi_clk;
  wire spi_miso;
  wire spi_mosi;

  // Synchronized SPI inputs
  wire spi_cs_n_sync;
  wire spi_clk_sync;
  wire spi_mosi_sync;

  assign spi_cs_n  = uio_in[4];
  assign spi_clk   = uio_in[5];
  assign spi_mosi  = uio_in[6];

  synchronizer #(.STAGES(2), .WIDTH(1)) synchronizer_spi_cs_n_inst (.clk(clk), .data_in(spi_cs_n), .data_out(spi_cs_n_sync));
  synchronizer #(.STAGES(2), .WIDTH(1)) synchronizer_spi_clk_inst  (.clk(clk), .data_in(spi_clk),  .data_out(spi_clk_sync));
  synchronizer #(.STAGES(2), .WIDTH(1)) synchronizer_spi_mosi_inst (.clk(clk), .data_in(spi_mosi), .data_out(spi_mosi_sync));  

  // The SPI instance
  spi_reg #(.ADDR_W(4)) i_spi_reg(
    .clk(clk),
    .rstb(rst_reg_n),
    .ena(1'b1),
    .spi_mosi(spi_mosi_sync),
    .spi_miso(spi_miso),
    .spi_clk(spi_clk_sync),
    .spi_cs_n(spi_cs_n_sync),
    .reg_addr(address),
    .reg_data_i(data_out),
    .reg_data_o(data_in),
    .reg_data_o_dv(data_valid)
  );

  // Assign outputs
  assign uio_out[3] = spi_miso;
  assign uio_oe[3] = 1;
  assign uio_out[7:4] = 0;
  assign uio_out[2:0] = 0;
  assign uio_oe[7:4] = 0;
  assign uio_oe[2:0] = 0;

  // Ignore unused inputs
  wire _unused = &{ena, uio_in[7], uio_in[3:0], 1'b0};

endmodule
