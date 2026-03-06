`timescale 1ns / 1ps

module uart_tx
  import uart_tx_pkg::*;
#(
  parameter logic [31:0] INIT_CONFIG_P = 32'h883
) (
  input  logic        clk_i,
  input  logic        reset_i,

  input  logic [31:0] config_i,
  input  logic [7:0]  data_i,
  input  logic        valid_i,
  output logic        ready_o,

  output logic        tx_o
);

  ////////// Signal Declarations //////////
  logic [31:0] config_q, config_d;
  logic        config_write;
  logic        config_valid;

  // NOTE: The configuration bus is 32 bits wide and it contains the following information.
  //
  // config_i[1:0] = data_width[1:0].
  // Sets the width of data to be transmitted.
  // 2'b00 -> 5 bits, 2'b01 -> 6 bits, 2'b10 -> 7 bits, 2'b11 -> 8bits.
  //
  // config_i[2] = parity.
  // Enables or Disables parity.
  // 1'b0 -> Disabled, 1'b1 -> Enabled.
  //
  // config_i[3] = parity_type.
  // Sets the parity type to Odd or Even. No effect if parity Disabled.
  // 1'b0 -> Odd parity, 1'b1 -> Even parity.
  //
  // config_i[4] = extra_stop.
  // Sets One or Two stops.
  // 1'b0 -> 1 stop, 1'b1 -> 2 stop bits.
  //
  // config_i[31:5] = baud_div[26:0].
  // Used to set the target baud rate. Set baud div to rounded integer of F_clk / F_baud.
  // e.g. With a clock rate of 125 MHz and target baud rate of 115200, I set baud_div to be
  // 125*10^6/115200 = 1085.
  // NOTE: if config_i[31:5] is set to 0, the transmitter will refuse to proceed until a nonzero
  // baud_divisor is presented.

  logic [1:0]  data_width;
  logic        parity;
  logic        parity_type;
  logic        extra_stop;
  logic [26:0] baud_div;

  // Controller signals
  logic    tx_valid;
  logic    baud_reset;
  logic    data_count_reset;
  logic    data_shift_en;
  tx_sel_e tx_sel;

  logic tx_parity_bit;

  logic tx_shift_lsb;

  logic data_done;

  logic baud;

  // Configuration register & signals
  assign config_d     = config_i;
  assign config_write = valid_i && ready_o;
  assign config_valid = config_i[31:5] != 27'd0;

  initial config_q = INIT_CONFIG_P;
  always_ff @(posedge clk_i) begin
    if (reset_i) config_q           <= INIT_CONFIG_P;
    else if (config_write) config_q <= config_d;
  end

  assign {
    baud_div,
    extra_stop,
    parity_type,
    parity,
    data_width
  } = config_q;

  // UART_TX Controller
  assign tx_valid = valid_i && config_valid && ready_o;

  tx_fsm tx_controller (
    .clk_i              (clk_i),
    .reset_i            (reset_i),
    .baud_i             (baud),
    .valid_i            (tx_valid),
    .data_done_i        (data_done),
    .parity_i           (parity),
    .extra_stop_i       (extra_stop),
    .ready_o            (ready_o),
    .baud_reset_o       (baud_reset),
    .data_count_reset_o (data_count_reset),
    .data_shift_en_o    (data_shift_en),
    .tx_sel_o           (tx_sel)
  );

  tx_shift tx_shift_unit (
    .clk_i  (clk_i),
    .load_i (tx_valid),
    .d_i    (data_i),
    .en_i   (data_shift_en),
    .q_o    (tx_shift_lsb)
  );

  tx_parity tx_parity_unit (
    .clk_i         (clk_i),
    .reset_i       (data_count_reset),
    .en_i          (data_shift_en),
    .bit_i         (tx_shift_lsb),
    .parity_type_i (parity_type),
    .parity_o      (tx_parity_bit)
  );

  tx_data_counter tx_data_counter_unit (
    .clk_i        (clk_i),
    .reset_i      (data_count_reset),
    .en_i         (data_shift_en),
    .data_width_i (data_width),
    .data_done_o  (data_done)
  );

  tx_baud_generator #(
    .WIDTH_P(27)
  ) tx_baud_generator_unit (
    .clk_i      (clk_i),
    .reset_i    (baud_reset),
    .baud_div_i (baud_div),
    .baud_o     (baud)
  );

  initial tx_o = 1'b1;
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      tx_o <= 1'b1;
    end else begin
      case (tx_sel)
        SEL_IDLE: tx_o   <= 1'b1;
        SEL_START: tx_o  <= 1'b0;
        SEL_DATA: tx_o   <= tx_shift_lsb;
        SEL_PARITY: tx_o <= tx_parity_bit;
        SEL_STOP: tx_o   <= 1'b1;
        default: tx_o    <= 1'b1;
      endcase // case (tx_sel)
    end
  end

endmodule
