`timescale 1ns / 1ps

module uart_regbank (
  input logic clk_i,
  input logic reset_i,

  /* NOTE: Register interface */

  // Write addr & data channel
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

  /* NOTE: Core interface */

  // CTRL signals
  output logic reset_rx_uart_o,
  output logic reset_tx_uart_o,
  output logic reset_rx_fifo_o,
  output logic reset_tx_fifo_o,
  output logic en_rx_o,
  output logic en_tx_o,

  // STATUS signals
  input logic rx_fifo_empty_i,
  input logic tx_fifo_empty_i,
  input logic rx_fifo_full_i,
  input logic tx_fifo_full_i,
  input logic overrun_error_i,
  input logic frame_error_i,
  input logic parity_error_i,
  input logic data_ready_i,

  // BAUD_DIV & MODE signals
  output logic [31:0] config_o,

  // THR signals
  input logic        thr_ready_i,
  output logic       thr_valid_o,
  output logic [7:0] thr_data_o,

  // RHR signals
  output logic      rhr_ready_o,
  input logic       rhr_valid_i,
  input logic [7:0] rhr_data_i
);

  // Register Addresses & Declarations
  localparam logic [2:0] CTRL_ADDR     = 3'd0;
  localparam logic [2:0] STATUS_ADDR   = 3'd1;
  localparam logic [2:0] BAUD_DIV_ADDR = 3'd2;
  localparam logic [2:0] MODE_ADDR     = 3'd3;
  localparam logic [2:0] THR_ADDR      = 3'd4;
  localparam logic [2:0] RHR_ADDR      = 3'd5;

  logic [31:0] CTRL;
  logic [31:0] STATUS;
  logic [31:0] BAUD_DIV;
  logic [31:0] MODE;
  logic [31:0] THR;
  logic [31:0] RHR;

  // Write control flow
  logic wr_start, wr_complete;
  assign wr_start = wr_ready_o && wr_valid_i;
  assign wr_complete = wr_ready_i && wr_valid_o;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      wr_ready_o <= 1'b1;
      wr_valid_o <= 1'b0;
    end else begin

      if (wr_start) begin
        wr_ready_o <= 1'b0;
        wr_valid_o <= 1'b1;
      end else if (wr_complete) begin
        wr_valid_o <= 1'b0;
        wr_ready_o <= 1'b1;
      end
    end
  end

  // Write response
  always_ff @(posedge clk_i) begin
    if (wr_start) begin
      wr_error_o <= ((wr_addr_i == STATUS_ADDR) || (wr_addr_i == RHR_ADDR)) ? 1'b1 : 1'b0;
    end
  end

  // Read control flow
  logic rd_start, rd_complete;
  assign rd_start = rd_ready_o && rd_valid_i;
  assign rd_complete = rd_ready_i && rd_valid_o;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      rd_ready_o <= 1'b1;
      rd_valid_o <= 1'b0;
    end else begin

      if (rd_start) begin
        rd_ready_o <= 1'b0;
        rd_valid_o <= 1'b1;
      end else if (rd_complete) begin
        rd_valid_o <= 1'b0;
        rd_ready_o <= 1'b1;
      end
    end
  end

  // Read response
  logic [2:0] rd_addr_q;

  always_ff @(posedge clk_i) begin
    if (rd_start) begin
      rd_error_o <= ((rd_addr_i != STATUS_ADDR) && (rd_addr_i != RHR_ADDR)) ? 1'b1 : 1'b0;
      rd_addr_q <= rd_addr_i;
    end
  end

  always_comb begin
    rd_data_o = 32'd0;
    case(rd_addr_q)
      STATUS_ADDR: rd_data_o = STATUS;
      RHR_ADDR: rd_data_o = RHR;
      default: rd_data_o = 32'd0;
    endcase
  end

  // Initial values & register resets
  initial begin
    CTRL     = 32'd60;           // Reset rx/tx fifo's and uarts, disable uarts
    STATUS   = 32'd385;
    BAUD_DIV = 32'd868;         // Baud rate: 115200 @ 100 MHz clk_i
    MODE     = 32'd3;           // 8N1
    THR      = 32'd0;
    RHR      = 32'd0;
  end

  // NOTE: Write only registers
  // CTRL register
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      // TODO: Better reset value?
      CTRL <= 32'd60;
    end else if (wr_start && (wr_addr_i == CTRL_ADDR)) begin
      if (wr_strb_i[0]) CTRL[7:0]   <= wr_data_i[7:0];
      if (wr_strb_i[1]) CTRL[15:8]  <= wr_data_i[15:8];
      if (wr_strb_i[2]) CTRL[23:16] <= wr_data_i[23:16];
      if (wr_strb_i[3]) CTRL[31:24] <= wr_data_i[31:24];
    end
  end


  // BAUD_DIV register
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      BAUD_DIV <= 32'd868;      // 115200 Baud @ 100 MHz clk_i
    end else if (wr_start && (wr_addr_i == BAUD_DIV_ADDR)) begin
      if (wr_strb_i[0]) BAUD_DIV[7:0]   <= wr_data_i[7:0];
      if (wr_strb_i[1]) BAUD_DIV[15:8]  <= wr_data_i[15:8];
      if (wr_strb_i[2]) BAUD_DIV[23:16] <= wr_data_i[23:16];
      if (wr_strb_i[3]) BAUD_DIV[31:24] <= wr_data_i[31:24];
    end
  end


  // MODE register
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      MODE <= 32'd3;            // 8N1
    end else if (wr_start && (wr_addr_i == MODE_ADDR)) begin
      if (wr_strb_i[0]) MODE[7:0]   <= wr_data_i[7:0];
      if (wr_strb_i[1]) MODE[15:8]  <= wr_data_i[15:8];
      if (wr_strb_i[2]) MODE[23:16] <= wr_data_i[23:16];
      if (wr_strb_i[3]) MODE[31:24] <= wr_data_i[31:24];
    end
  end

  // THR register
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      THR <= 32'd0;
    end else if (wr_start && (wr_addr_i == THR_ADDR)) begin
      if (wr_strb_i[0]) THR[7:0]   <= wr_data_i[7:0];
      if (wr_strb_i[1]) THR[15:8]  <= wr_data_i[15:8];
      if (wr_strb_i[2]) THR[23:16] <= wr_data_i[23:16];
      if (wr_strb_i[3]) THR[31:24] <= wr_data_i[31:24];
    end
  end

  ////////// Core interface //////////

  // CTRL signals
  always_comb begin
    // TODO: test reset_* w reset_i signal.
    reset_rx_uart_o = CTRL[5];
    reset_tx_uart_o = CTRL[4];
    reset_rx_fifo_o = CTRL[3];
    reset_tx_fifo_o = CTRL[2];
    en_rx_o = CTRL[1];
    en_tx_o = CTRL[0];
  end

  // BAUD_DIV & MODE signals
  assign config_o = {BAUD_DIV[26:0], MODE[4:0]};

  // STATUS signals
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      // TODO: is this reset necessary?
      STATUS <= 32'd385;
    end else begin
      STATUS[8:5] <= {
        rx_fifo_empty_i,
        tx_fifo_empty_i,
        rx_fifo_full_i,
        tx_fifo_full_i
      };

      // overrun bit
      if (rd_start && (rd_addr_i == STATUS_ADDR)) begin
        STATUS[4] <= 1'b0;
      end else begin
        STATUS[4] <= STATUS[4] || overrun_error_i;
      end

      if (data_ready_i) begin
        STATUS[3] <= parity_error_i;
        STATUS[2] <= frame_error_i;
      end

      STATUS[1] <= data_ready_i;

      // STATUS[0] bit is same as thr_valid_o
      if (wr_start && (wr_addr_i == THR_ADDR)) begin
        STATUS[0] <= 1'b0;
      end else if (thr_ready_i && thr_valid_o) begin
        STATUS[0] <= 1'b1;
      end

    end
  end


  // THR signals
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      thr_valid_o <= 1'b0;
    end else if (wr_start && (wr_addr_i == THR_ADDR)) begin
      thr_valid_o <= 1'b1;
    end else if (thr_ready_i && thr_valid_o) begin
      thr_valid_o <= 1'b0;
    end
  end

  assign thr_data_o = THR[7:0];

  // RHR signals
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      RHR <= 32'd0;
    end else begin
      if (rd_start && (rd_addr_i == RHR_ADDR) && rhr_valid_i) begin
        // Sample the top of rx fifo
        RHR[7:0] <= rhr_data_i;
      end
    end
  end

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      rhr_ready_o <= 1'b0;
    end else begin

      // pop only a single item off the rx fifo
      if (rhr_ready_o == 1'b1) begin
        rhr_ready_o <= 1'b0;
      end else if (rd_start && (rd_addr_i == RHR_ADDR) && rhr_valid_i) begin
        rhr_ready_o <= 1'b1;
      end
    end
  end

endmodule
