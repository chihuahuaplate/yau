`timescale 1ns / 1ps

module uart (
  input logic         clk_i,
  input logic         resetn_i,
  // NOTE: AXI Lite interface
  // AW Channel
  input logic [2:0]   s_axil_awaddr_i,
  input logic [2:0]   s_axil_awprot_i,
  input logic         s_axil_awvalid_i,
  output logic        s_axil_awready_o,
  // W Channel
  input logic [31:0]  s_axil_wdata_i,
  input logic [3:0]   s_axil_wstrb_i,
  input logic         s_axil_wvalid_i,
  output logic        s_axil_wready_o,
  // B Channel
  output logic [1:0]  s_axil_bresp_o,
  output logic        s_axil_bvalid_o,
  input logic         s_axil_bready_i,
  // AR Channel
  input logic [2:0]   s_axil_araddr_i,
  input logic [2:0]   s_axil_arprot_i,
  input logic         s_axil_arvalid_i,
  output logic        s_axil_arready_o,
  // R Channel
  output logic [31:0] s_axil_rdata_o,
  output logic [1:0]  s_axil_rresp_o,
  output logic        s_axil_rvalid_o,
  input logic         s_axil_rready_i,

  // NOTE: UART pins
  input logic         rx_i,
  output logic        tx_o
);

  // Core signals
  logic reset_rx_uart_lo;
  logic reset_tx_uart_lo;
  logic reset_rx_fifo_lo;
  logic reset_tx_fifo_lo;
  logic rx_fifo_empty_li;
  logic tx_fifo_empty_li;
  logic rx_fifo_full_li;
  logic tx_fifo_full_li;
  logic overrun_error_li;
  logic parity_error_li;
  logic frame_error_li;
  logic [31:0] config_lo;

  uart_registers uart_registers_u (
    .clk_i(clk_i),
    .resetn_i(resetn_i),
    // AXI Lite connections
    .s_axil_awaddr_i(s_axil_awaddr_i),
    .s_axil_awprot_i(s_axil_awprot_i),
    .s_axil_awvalid_i(s_axil_awvalid_i),
    .s_axil_awready_o(s_axil_awready_o),
    .s_axil_wdata_i(s_axil_wdata_i),
    .s_axil_wstrb_i(s_axil_wstrb_i),
    .s_axil_wvalid_i(s_axil_wvalid_i),
    .s_axil_wready_o(s_axil_wready_o),
    .s_axil_bresp_o(s_axil_bresp_o),
    .s_axil_bvalid_o(s_axil_bvalid_o),
    .s_axil_bready_i(s_axil_bready_i),
    .s_axil_araddr_i(s_axil_araddr_i),
    .s_axil_arprot_i(s_axil_arprot_i),
    .s_axil_arvalid_i(s_axil_arvalid_i),
    .s_axil_arready_o(s_axil_arready_o),
    .s_axil_rdata_o(s_axil_rdata_o),
    .s_axil_rresp_o(s_axil_rresp_o),
    .s_axil_rvalid_o(s_axil_rvalid_o),
    .s_axil_rready_i(s_axil_rready_i),
    // Uart core connections
    // CTRL
    .reset_rx_uart_o(reset_rx_uart_lo),
    .reset_tx_uart_o(reset_tx_uart_lo),
    .reset_rx_fifo_o(reset_rx_fifo_lo),
    .reset_tx_fifo_o(reset_tx_fifo_lo),
    // STATUS
    .rx_fifo_empty_i(rx_fifo_empty_li),
    .tx_fifo_empty_i(tx_fifo_empty_li),
    .rx_fifo_full_i(rx_fifo_full_li),
    .tx_fifo_full_i(tx_fifo_full_li),
    .overrun_error_i(overrun_error_li),
    .parity_error_i(parity_error_li),
    .frame_error_i(frame_error_li),
    // BAUD_DIV & MODE
    .config_o(config_lo),
    // THR
    .thr_ready_i(tx_fifo_ready_lo),
    .thr_valid_o(thr_valid_lo),
    .thr_data_o(thr_data_lo),
    // RHR
    .rhr_ready_o(rhr_ready_lo),
    .rhr_valid_i(rx_fifo_valid_lo),
    .rhr_data_i(rhr_data_li)
  );

  always_comb begin
    rx_fifo_empty_li = !rx_fifo_valid_lo;
    tx_fifo_empty_li = !tx_fifo_valid_lo;
    rx_fifo_full_li  = !rx_fifo_ready_lo;
    tx_fifo_full_li  = !tx_fifo_ready_lo;
  end

  ////////// Transmitter //////////

  // THR signals
  logic thr_valid_lo;
  logic [7:0] thr_data_lo;
  // TX FIFO signals
  logic       tx_fifo_ready_lo;

  fifo_fwft #(
    .width_p(8),
    .depth_p(32)
  ) tx_fifo (
    .clk_i(clk_i),
    .reset_i(reset_tx_fifo_lo),
    .ready_o(tx_fifo_ready_lo),
    .valid_i(thr_valid_lo),
    .data_i(thr_data_lo),
    .ready_i(tx_uart_ready_lo),
    .valid_o(tx_fifo_valid_lo),
    .data_o(tx_fifo_data_lo)
  );

  // TX FIFO signals
  logic       tx_fifo_valid_lo;
  logic [7:0] tx_fifo_data_lo;
  // TX UART signals
  logic       tx_uart_ready_lo;

  logic [31:0] tx_config;
  assign tx_config = {config_lo[31:5] << 4, config_lo[4:0]};

  uart_tx_core tx_uart (
    .clk_i(clk_i),
    .reset_i(reset_tx_uart_lo),
    .config_i(tx_config),
    .ready_o(tx_uart_ready_lo),
    .valid_i(tx_fifo_valid_lo),
    .data_i(tx_fifo_data_lo),
    .tx_o(tx_o)
  );

  ////////// Reciever //////////

  // RHR signals
  logic       rhr_ready_lo;
  logic [7:0] rhr_data_li;
  // RX FIFO signals
  logic       rx_fifo_valid_lo;
  logic [9:0] rx_fifo_data_lo;

  always_comb begin
    rhr_data_li      = rx_fifo_data_lo[7:0];
    frame_error_li   = rx_fifo_data_lo[8];
    parity_error_li  = rx_fifo_data_lo[9];
  end

  fifo_fwft #(
    .width_p(10),
    .depth_p(32)
  ) rx_fifo (
    .clk_i(clk_i),
    .reset_i(reset_rx_fifo_lo),
    .ready_o(rx_fifo_ready_lo),
    .valid_i(rx_uart_valid_lo),
    .data_i(rx_fifo_data_li),
    .ready_i(rhr_ready_lo),
    .valid_o(rx_fifo_valid_lo),
    .data_o(rx_fifo_data_lo)
  );

  logic rx_fifo_ready_lo;
  logic [9:0] rx_fifo_data_li;

  logic [7:0] rx_uart_data_lo;
  logic       rx_uart_valid_lo;
  logic       rx_uart_frame_error_lo;
  logic       rx_uart_parity_error_lo;
  logic       rx_uart_overrun_error_lo;

  always_comb begin
    rx_fifo_data_li = {rx_uart_parity_error_lo, rx_uart_frame_error_lo, rx_uart_data_lo};
    overrun_error_li = rx_uart_overrun_error_lo;
  end

  uart_rx_core rx_uart (
    .clk_i(clk_i),
    .reset_i(reset_rx_uart_lo),
    .config_i(config_lo),
    .rx_i(rx_lo),
    .ready_i(rx_fifo_ready_lo),
    .valid_o(rx_uart_valid_lo),
    .data_o(rx_uart_data_lo),
    .frame_error_o(rx_uart_frame_error_lo),
    .parity_error_o(rx_uart_parity_error_lo),
    .overrun_error_o(rx_uart_overrun_error_lo)
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
