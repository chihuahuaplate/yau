`timescale 1ns / 1ps

module uart_registers (
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
  /* NOTE: Core interface */
  // CTRL signals
  output logic        reset_rx_uart_o,
  output logic        reset_tx_uart_o,
  output logic        reset_rx_fifo_o,
  output logic        reset_tx_fifo_o,

  // STATUS signals
  input logic         rx_fifo_empty_i,
  input logic         tx_fifo_empty_i,
  input logic         rx_fifo_full_i,
  input logic         tx_fifo_full_i,
  input logic         overrun_error_i,
  input logic         frame_error_i,
  input logic         parity_error_i,

  // BAUD_DIV & MODE signals
  output logic [31:0] config_o,

  // THR signals
  input logic         thr_ready_i,
  output logic        thr_valid_o,
  output logic [7:0]  thr_data_o,

  // RHR signals
  output logic        rhr_ready_o,
  input logic         rhr_valid_i,
  input logic [7:0]   rhr_data_i
);

  // Register address definitions
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

  logic  wr_start, wr_complete;
  assign wr_start = (s_axil_wready_o && s_axil_wvalid_i) && (s_axil_wready_o && s_axil_wvalid_i);
  assign wr_complete = (s_axil_bvalid_o && s_axil_bready_i);

  logic  rd_start, rd_complete;
  assign rd_start = (s_axil_arready_o && s_axil_arvalid_i);
  assign rd_complete = (s_axil_rvalid_o && s_axil_rready_i);

  // AXI Lite Write & Read state machines

  // Write state machine
  typedef enum logic [0:0] {
    AXIL_LISTEN,
    AXIL_RESPOND
  } axil_state_e;

  axil_state_e wr_state_d, wr_state_q;
  logic awready_d, awready_q;
  logic wready_d, wready_q;
  logic bvalid_d, bvalid_q;
  logic [1:0] bresp_d, bresp_q;

  always_ff @(posedge clk_i) begin
    if (!resetn_i) begin
      wr_state_q <= AXIL_LISTEN;
      awready_q <= 1'b1;
      wready_q <= 1'b1;
      bvalid_q <= 1'b0;
      bresp_q <= 2'b00;
    end else begin
      wr_state_q <= wr_state_d;
      awready_q <= awready_d;
      wready_q <= wready_d;
      bvalid_q <= bvalid_d;
      bresp_q <= bresp_d;
    end
  end

  always_comb begin
    // default assigns
    wr_state_d = wr_state_q;
    awready_d = awready_q;
    wready_d = wready_q;
    bvalid_d = bvalid_q;
    bresp_d = bresp_q;

    case (wr_state_q)
      AXIL_LISTEN: begin
        if (wr_start) begin
          wr_state_d = AXIL_RESPOND;
          awready_d = 1'b0;
          wready_d = 1'b0;
          bvalid_d = 1'b1;
          bresp_d = ((s_axil_awaddr_i == STATUS_ADDR) || (s_axil_awaddr_i == RHR_ADDR)) ?
                    2'b10 : 2'b00;
        end
      end
      AXIL_RESPOND: begin
        if (wr_complete) begin
          wr_state_d = AXIL_LISTEN;
          awready_d = 1'b1;
          wready_d = 1'b1;
          bvalid_d = 1'b0;
        end
      end
    endcase

    // outputs
    s_axil_awready_o = awready_q;
    s_axil_wready_o = wready_q;
    s_axil_bvalid_o = bvalid_q;
    s_axil_bresp_o = bresp_q;
  end


  // Read state machine
  axil_state_e rd_state_d, rd_state_q;
  logic arready_d, arready_q;
  logic rvalid_d, rvalid_q;
  logic [31:0] rdata_d, rdata_q;

  always_ff @(posedge clk_i) begin
    if (!resetn_i) begin
      rd_state_q <= AXIL_LISTEN;
      arready_q <= 1'b1;
      rvalid_q <= 1'b0;
      rdata_q <= 32'h0;
    end else begin
      rd_state_q <= rd_state_d;
      arready_q <= arready_d;
      rvalid_q <= rvalid_d;
      rdata_q <= rdata_d;
    end
  end

  always_comb begin
    // default assigns
    rd_state_d = rd_state_q;
    arready_d = arready_q;
    rvalid_d = rvalid_q;
    rdata_d = rdata_q;

    case(rd_state_q)
      AXIL_LISTEN: begin
        if (rd_start) begin
          rd_state_d = AXIL_RESPOND;
          arready_d = 1'b0;
          rvalid_d = 1'b1;

          // TODO: Implement data forwarding on s_axil_rdata_o
          case(s_axil_araddr_i)
            CTRL_ADDR: rdata_d = CTRL;
            STATUS_ADDR: begin


              // NOTE: Data forwarding of the STATUS register is
              // necessary for when there is a single item in the RX
              // FIFO and there is a back to back READ of RHR & STATUS
              // register with minimal delay between both, that is,
              // when a READ is initiated the result is READ
              // as soon as possible so the next read can be initiated.
              //
              // In this situation when a READ at RHR is initiated,
              // the pop signal on the rx fifo is pulsed for one
              // cycle. The pop can occur simultaneously as the RHR
              // read data is transferred on the R channel. Because
              // STATUS[1] is the registering of rhr_valid_i
              // (otherwise known as rx_fifo_valid_o) it takes on the
              // value of rhr_valid_i before it is deasserted. At the
              // next clock edge if a READ at the STATUS register is
              // initiated rdata_o would take on the current value
              // STATUS[1] which is still the value of 1 whereas in
              // reality the FIFO is empty. In this case we should
              // forward the NEXT STATE of STATUS rather than the
              // CURRENT STATE. If we didn't we'd be lying to the user
              // that RHR is ready to be read for another character.

              if (STATUS[1] && !STATUS_d[1]) begin
              rdata_d = STATUS_d;
              end else begin
                rdata_d = STATUS;
              end
            end
            BAUD_DIV_ADDR: rdata_d = BAUD_DIV;
            MODE_ADDR: rdata_d = MODE;
            THR_ADDR: rdata_d = THR;
            RHR_ADDR: rdata_d = RHR;
          endcase
        end
      end
      AXIL_RESPOND: begin
        if (rd_complete) begin
          rd_state_d = AXIL_LISTEN;
          arready_d = 1'b1;
          rvalid_d = 1'b0;
        end
      end
    endcase

    // outputs
    s_axil_rresp_o = 2'b00;            // Reads always return status of OKAY
    s_axil_arready_o = arready_q;
    s_axil_rvalid_o = rvalid_q;
    s_axil_rdata_o = rdata_q;
  end

  // Core interfacing signals

  // CTRL register
  // Init value and reset sets the rx and tx uarts and fifos into reset.
  // User needs to write to these to deactivate reset for operation.
  initial CTRL[31:0] = 32'hF;
  always_ff @(posedge clk_i) begin
    if (!resetn_i) begin
      CTRL <= 32'hF;
    end else if (wr_start && (s_axil_awaddr_i == CTRL_ADDR)) begin
      if (s_axil_wstrb_i[0]) CTRL[7:0]   <= s_axil_wdata_i[7:0];
      if (s_axil_wstrb_i[1]) CTRL[15:8]  <= s_axil_wdata_i[15:8];
      if (s_axil_wstrb_i[2]) CTRL[23:16] <= s_axil_wdata_i[23:16];
      if (s_axil_wstrb_i[3]) CTRL[31:24] <= s_axil_wdata_i[31:24];
    end
  end

  assign reset_rx_uart_o = CTRL[3];
  assign reset_tx_uart_o = CTRL[2];
  assign reset_rx_fifo_o = CTRL[1];
  assign reset_tx_fifo_o = CTRL[0];

  // BAUD_DIV register
  // Sets baud rate to 115200 @ 100 MHz clk_i
  initial BAUD_DIV[31:0] = 32'h364;
  always_ff @(posedge clk_i) begin
    if (!resetn_i) begin
      BAUD_DIV <= 32'h364;
    end else if (wr_start && (s_axil_awaddr_i == BAUD_DIV_ADDR)) begin
      if (s_axil_wstrb_i[0]) BAUD_DIV[7:0]   <= s_axil_wdata_i[7:0];
      if (s_axil_wstrb_i[1]) BAUD_DIV[15:8]  <= s_axil_wdata_i[15:8];
      if (s_axil_wstrb_i[2]) BAUD_DIV[23:16] <= s_axil_wdata_i[23:16];
      if (s_axil_wstrb_i[3]) BAUD_DIV[31:24] <= s_axil_wdata_i[31:24];
    end
  end

  assign config_o[31:5] = BAUD_DIV[26:0];

  // MODE register
  // Sets UARTs to expect 8 bits, No parity, 1 Stop bit (8N1)
  initial MODE[31:0] = 32'h3;
  always_ff @(posedge clk_i) begin
    if (!resetn_i) begin
      MODE <= 32'h3;
    end else if (wr_start && (s_axil_awaddr_i == MODE_ADDR)) begin
      if (s_axil_wstrb_i[0]) MODE[7:0]   <= s_axil_wdata_i[7:0];
      if (s_axil_wstrb_i[1]) MODE[15:8]  <= s_axil_wdata_i[15:8];
      if (s_axil_wstrb_i[2]) MODE[23:16] <= s_axil_wdata_i[23:16];
      if (s_axil_wstrb_i[3]) MODE[31:24] <= s_axil_wdata_i[31:24];
    end
  end

  assign config_o[4:0] = MODE[4:0];

  // THR register
  initial THR[31:0] = 32'h0;
  always_ff @(posedge clk_i) begin
    if (!resetn_i) begin
      THR <= 32'h0;
      thr_valid_o <= 1'b0;
    end else if (wr_start && (s_axil_awaddr_i == THR_ADDR)) begin
      if (s_axil_wstrb_i[0]) THR[7:0]   <= s_axil_wdata_i[7:0];
      if (s_axil_wstrb_i[1]) THR[15:8]  <= s_axil_wdata_i[15:8];
      if (s_axil_wstrb_i[2]) THR[23:16] <= s_axil_wdata_i[23:16];
      if (s_axil_wstrb_i[3]) THR[31:24] <= s_axil_wdata_i[31:24];
      thr_valid_o <= 1'b1;
    end else if (thr_valid_o && thr_ready_i) begin
      thr_valid_o <= 1'b0;
    end
  end

  assign thr_data_o = THR[7:0];

  // RHR register
  initial RHR[31:0] = 32'h0;
  always_ff @(posedge clk_i) begin
    if (!resetn_i) begin
      RHR <= 32'h0;
      rhr_ready_o <= 1'b0;
    end else begin
      if (rhr_valid_i) begin
        RHR[7:0] <= rhr_data_i;
      end

      // On a read @RHR & the status register indicates RHR is READY
      // to read (STATUS[1] == 1'b1) we pulse pop for a single cycle.
      if (rhr_ready_o) begin
        rhr_ready_o <= 1'b0;
      end else if (rd_start && (s_axil_araddr_i == RHR_ADDR) && STATUS[1]) begin
        rhr_ready_o <= 1'b1;
      end
    end
  end

  // STATUS register
  logic [31:0] STATUS_d;

  initial STATUS[31:0] = 32'h181;
  always_ff @(posedge clk_i) begin
    if (!resetn_i) begin
      STATUS <= 32'h181;
    end else begin
      STATUS <= STATUS_d;
    end
  end

  always_comb begin
    // default assigns
    STATUS_d = STATUS;

    STATUS_d[8:5] = {
      rx_fifo_empty_i,
      tx_fifo_empty_i,
      rx_fifo_full_i,
      tx_fifo_full_i
    };

    if (rd_start && (s_axil_araddr_i == STATUS_ADDR) && STATUS[4]) begin
      STATUS_d[4] = 1'b0;
    end else begin
      STATUS_d[4] = STATUS[4] || overrun_error_i;
    end

    STATUS_d[3] = parity_error_i;
    STATUS_d[2] = frame_error_i;
    STATUS_d[1] = rhr_valid_i;

    // STATUS[0] indicates THR has valid data waiting for the TX FIFO
    // to receive.
    if (wr_start && (s_axil_awaddr_i == THR_ADDR)) begin
      STATUS_d[0] <= 1'b1;
    end else if (thr_valid_o && thr_ready_i) begin
      STATUS_d[0] <= 1'b0;
    end
  end

endmodule
