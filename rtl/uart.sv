`timescale 1ns / 1ps

module uart (
  input logic         clk_i,
  input logic         reset_i,

  /* NOTE: Register interface */
  input logic [2:0]  wr_addr_i,
  input logic [31:0] wr_data_i,
  input logic [3:0]  wr_strb_i,
  output logic       wr_ready_o,
  input logic        wr_valid_i,

  // write response channel
  input logic  wr_ready_i,
  output logic wr_valid_o,
  output logic wr_error_o,

  // read addr channel
  input logic [2:0] rd_addr_i,
  output logic      rd_ready_o,
  input logic       rd_valid_i,

  // read response channel
  input logic         rd_ready_i,
  output logic        rd_valid_o,
  output logic [31:0] rd_data_o,
  output logic        rd_error_o,

  // uart pins
  output logic        tx_o,
  input logic         rx_i
);

  // Core signals
  logic reset_rx_uart_lo;
  logic reset_tx_uart_lo;
  logic reset_rx_fifo_lo;
  logic reset_tx_fifo_lo;
  logic en_rx_lo;
  logic en_tx_lo;

  logic rx_fifo_empty_li;
  logic tx_fifo_empty_li;
  logic rx_fifo_full_li;
  logic tx_fifo_full_li;
  logic overrun_error_li;
  logic parity_error_li;
  logic frame_error_li;
  logic data_ready_li;

  logic [31:0] config_lo;

  always_comb begin
    rx_fifo_empty_li = !rx_fifo_valid_lo;
    tx_fifo_empty_li = !tx_fifo_valid_lo;
    rx_fifo_full_li  = !rx_fifo_ready_lo;
    tx_fifo_full_li  = !tx_fifo_ready_lo;
    data_ready_li    = rhr_valid_li;
  end

  uart_regbank uart_registers (
    .clk_i(clk_i),
    .reset_i(reset_i),
    // Register interface
    .wr_addr_i(wr_addr_i),
    .wr_data_i(wr_data_i),
    .wr_strb_i(wr_strb_i),
    .wr_ready_o(wr_ready_o),
    .wr_valid_i(wr_valid_i),
    .wr_ready_i(wr_ready_i),
    .wr_valid_o(wr_valid_o),
    .wr_error_o(wr_error_o),
    .rd_addr_i(rd_addr_i),
    .rd_ready_o(rd_ready_o),
    .rd_valid_i(rd_valid_i),
    .rd_ready_i(rd_ready_i),
    .rd_valid_o(rd_valid_o),
    .rd_data_o(rd_data_o),
    .rd_error_o(rd_error_o),
    // Core interface
    // CTRL
    .reset_rx_uart_o(reset_rx_uart_lo),
    .reset_tx_uart_o(reset_tx_uart_lo),
    .reset_rx_fifo_o(reset_rx_fifo_lo),
    .reset_tx_fifo_o(reset_tx_fifo_lo),
    .en_rx_o(en_rx_lo),
    .en_tx_o(en_tx_lo),
    // STATUS
    .rx_fifo_empty_i(rx_fifo_empty_li),
    .tx_fifo_empty_i(tx_fifo_empty_li),
    .rx_fifo_full_i(rx_fifo_full_li),
    .tx_fifo_full_i(tx_fifo_full_li),
    .overrun_error_i(overrun_error_li),
    .parity_error_i(parity_error_li),
    .frame_error_i(frame_error_li),
    .data_ready_i(data_ready_li),
    // BAUD_DIV & MODE
    .config_o(config_lo),
    // THR
    .thr_ready_i(thr_ready_li),
    .thr_valid_o(thr_valid_lo),
    .thr_data_o(thr_data_lo),
    // RHR
    .rhr_ready_o(rhr_ready_lo),
    .rhr_valid_i(rhr_valid_li),
    .rhr_data_i(rhr_data_li)
  );

  ////////// Transmitter //////////
  // thr signals
  logic thr_ready_li;
  logic thr_valid_lo;
  logic [7:0] thr_data_lo;

  // tx fifo signals
  logic       tx_fifo_ready_lo;
  logic       tx_fifo_valid_li;
  logic [7:0] tx_fifo_data_li;

  always_comb begin
    tx_fifo_data_li = thr_data_lo;
    tx_fifo_valid_li = thr_valid_lo;
    thr_ready_li = tx_fifo_ready_lo;
  end

  fifo_fwft #(
    .width_p(8),
    .depth_p(32)
  ) tx_fifo (
    .clk_i(clk_i),
    .reset_i(reset_tx_fifo_lo),
    .ready_o(tx_fifo_ready_lo),
    .valid_i(tx_fifo_valid_li),
    .data_i(tx_fifo_data_li),
    .ready_i(tx_fifo_ready_li),
    .valid_o(tx_fifo_valid_lo),
    .data_o(tx_fifo_data_lo)
  );

  logic       tx_fifo_ready_li;
  logic       tx_fifo_valid_lo;
  logic [7:0] tx_fifo_data_lo;

  logic       tx_uart_ready_lo;
  logic       tx_uart_valid_li;
  logic [7:0] tx_uart_data_li;

  always_comb begin
    tx_uart_data_li = tx_fifo_data_lo;
    tx_uart_valid_li = tx_fifo_valid_lo && en_tx_lo;
    tx_fifo_ready_li = tx_uart_ready_lo && en_tx_lo;
  end

  uart_tx_core tx_uart (
    .clk_i(clk_i),
    .reset_i(reset_tx_uart_lo),
    .config_i(config_lo),
    .ready_o(tx_uart_ready_lo),
    .valid_i(tx_uart_valid_li),
    .data_i(tx_uart_data_li),
    .tx_o(tx_o)
  );

  ////////// Reciever //////////

  logic       rhr_ready_lo;
  logic       rhr_valid_li;
  logic [7:0] rhr_data_li;

  logic       rx_fifo_valid_lo;
  logic [9:0] rx_fifo_data_lo;
  logic       rx_fifo_ready_li;

  always_comb begin
    rhr_data_li      = rx_fifo_data_lo[7:0];
    frame_error_li   = rx_fifo_data_lo[8];
    parity_error_li  = rx_fifo_data_lo[9];
    rhr_valid_li     = rx_fifo_valid_lo;
    rx_fifo_ready_li = rhr_ready_lo;
  end

  fifo_fwft #(
    .width_p(10),
    .depth_p(32)
  ) rx_fifo (
    .clk_i(clk_i),
    .reset_i(reset_rx_fifo_lo),
    .ready_o(rx_fifo_ready_lo),
    .valid_i(rx_fifo_valid_li),
    .data_i(rx_fifo_data_li),
    .ready_i(rx_fifo_ready_li),
    .valid_o(rx_fifo_valid_lo),
    .data_o(rx_fifo_data_lo)
  );

  logic rx_fifo_ready_lo;
  logic rx_fifo_valid_li;
  logic [9:0] rx_fifo_data_li;

  logic [7:0] rx_uart_data_lo;
  logic       rx_uart_valid_lo;
  logic       rx_uart_frame_error_lo;
  logic       rx_uart_parity_error_lo;

  always_comb begin
    rx_fifo_data_li = {rx_uart_parity_error_lo, rx_uart_frame_error_lo, rx_uart_data_lo};
    rx_fifo_valid_li = rx_uart_valid_lo && en_rx_lo;
    overrun_error_li = (rx_uart_valid_lo && !rx_fifo_ready_lo) && en_rx_lo;
  end

  uart_rx_core rx_uart (
    .clk_i(clk_i),
    .reset_i(reset_rx_uart_lo),
    .config_i(config_lo),
    .rx_i(rx_lo),
    .data_o(rx_uart_data_lo),
    .valid_o(rx_uart_valid_lo),
    .frame_error_o(rx_uart_frame_error_lo),
    .parity_error_o(rx_uart_parity_error_lo)
  );

  logic rx_lo;

  synchronizer #(
    .width_p(3)
  ) sync_rx_i (
    .clk_i(clk_i),
    .async_i(rx_i),
    .sync_o(rx_lo)
  );

endmodule
