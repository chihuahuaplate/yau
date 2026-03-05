`timescale 1ns / 1ps

module tx_fsm
  import uart_tx_pkg::*;
  (
  input           clk_i,
  input           reset_i,
  input           baud_i,
  input           valid_i,
  input           data_done_i,

  // CONFIGURATION
  input           parity_i,
  input           extra_stop_i,

  output logic    ready_o,
  output logic    baud_reset_o,
  output logic    data_count_reset_o,
  output logic    data_shift_en_o,
  output tx_sel_e tx_sel_o
  );

  tx_state_e tx_r, tx_n;

  // state register
  always_ff @(posedge clk_i) begin
    if (reset_i) tx_r <= IDLE;
    else tx_r <= tx_n;
  end

  // next state logic
  always_comb begin
    tx_n = tx_r;

    case (tx_r)
      IDLE: begin
        if (valid_i) tx_n = START;
      end

      START: begin
        if (baud_i) tx_n = DATA;
      end

      DATA: begin
        if (baud_i && data_done_i && parity_i) tx_n  = PARITY;
        if (baud_i && data_done_i && !parity_i) tx_n = STOP;
      end

      PARITY: begin
        if (baud_i) tx_n = STOP;
      end

      STOP: begin
        if (baud_i && extra_stop_i) tx_n  = EXTRA_STOP;
        if (baud_i && !extra_stop_i) tx_n = IDLE;
      end

      EXTRA_STOP: begin
        if (baud_i) tx_n = IDLE;
      end

      default: tx_n = tx_r;
    endcase // case (tx_r)
  end

  // output logic
  always_comb begin
    ready_o            = (tx_r == IDLE);
    baud_reset_o       = (tx_r == IDLE) && (tx_n == START);
    data_count_reset_o = (tx_r == START) && (tx_n == DATA);
    data_shift_en_o    = (tx_r == DATA && baud_i);

    case (tx_r)
      IDLE: tx_sel_o       = SEL_IDLE;
      START: tx_sel_o      = SEL_START;
      DATA: tx_sel_o       = SEL_DATA;
      PARITY: tx_sel_o     = SEL_PARITY;
      STOP: tx_sel_o       = SEL_STOP;
      EXTRA_STOP: tx_sel_o = SEL_STOP;

      default: tx_sel_o    = SEL_IDLE;
    endcase // case (tx_r)

  end

endmodule
