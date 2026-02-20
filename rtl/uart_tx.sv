`timescale 1ns / 1ps

module uart_tx import uart_tx_pkg::*;
  #(parameter [31:0] INIT_CONFIG_P = 32'h883
    // INIT_CONFIG_P sets config_r to the following:
    // Assuming 125 MHz clock
    // Baud rate   : 115200
    // Data bits   : 8
    // Parity      : Absent (0)
    // Parity type : Odd (0)
    // Extra stop  : Absent (0)
    )
  (input        clk_i,
   input        reset_i,

   // config interface
   input [31:0] config_i,

   input [7:0]  data_i,
   input        valid_i,
   output       ready_o,

   output logic tx_o
   );

  // Signal declarations

  // Configuration signals
  logic [31:0] config_r;

  logic [1:0] data_width;
  logic       parity;
  logic       parity_type;
  logic       extra_stop;
  logic [26:0] baud_div;

  assign {baud_div, extra_stop, parity_type, parity, data_width} = config_r;

  // Ensure bits corresponding to baud_div neq Zero
  wire config_valid = (config_i[31:5] != 0);
  wire tx_valid = valid_i && config_valid;

  // FSM signals
  logic baud_reset;
  logic data_count_reset;
  logic data_shift_en;
  tx_sel_t tx_sel;

  // Parity signals
  logic tx_parity_bit;
  
  // Shift register
  wire  tx_shift_load = valid_i && ready_o;
  logic tx_shift_lsb;

  // Data counter
  logic data_done;

  // Baud generator
  logic baud;

  initial config_r = INIT_CONFIG_P;
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      config_r <= INIT_CONFIG_P;
    end else if (valid_i && ready_o) begin
      config_r <= config_i;
    end
  end
  
  tx_fsm tx_controller
    (.clk_i(clk_i),
     .reset_i(reset_i),
     .baud_i(baud),
     .valid_i(tx_valid),
     .data_done_i(data_done),
     .parity_i(parity),
     .extra_stop_i(extra_stop),
     .ready_o(ready_o),
     .baud_reset_o(baud_reset),
     .data_count_reset_o(data_count_reset),
     .data_shift_en_o(data_shift_en),
     .tx_sel_o(tx_sel)
     );

  tx_shift tx_shift_unit
    (.clk_i(clk_i),
     .load_i(tx_shift_load),
     .d_i(data_i),
     .en_i(data_shift_en),
     .q_o(tx_shift_lsb)
     );

  tx_parity tx_parity_unit
    (.clk_i(clk_i),
     .reset_i(data_count_reset),
     .en_i(data_shift_en),
     .bit_i(tx_shift_lsb),
     .parity_type_i(parity_type),
     .parity_o(tx_parity_bit)
     );

  tx_data_counter tx_data_counter_unit
    (.clk_i(clk_i),
     .reset_i(data_count_reset),
     .en_i(data_shift_en),
     .data_width_i(data_width),
     .data_done_o(data_done)
     );

  tx_baud_generator #(.WIDTH_P(27))
  tx_baud_generator_unit
    (.clk_i(clk_i),
     .reset_i(baud_reset),
     .baud_div_i(baud_div),
     .baud_o(baud)
     );

  initial tx_o = 1'b1;
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      tx_o <= 1'b1;
    end else begin
      case (tx_sel)
        SEL_IDLE: tx_o <= 1'b1;
        SEL_START: tx_o <= 1'b0;
        SEL_DATA: tx_o <= tx_shift_lsb;
        SEL_PARITY: tx_o <= tx_parity_bit;
        SEL_STOP: tx_o <= 1'b1;

        default: tx_o <= 1'b1;
      endcase
    end
  end

endmodule

