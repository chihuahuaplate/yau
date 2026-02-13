`timescale 1ns / 1ps

// NOTE: baud_div_i = 0 *should* never occur.
// The transmitter FSM does will not transmit if baud_div is 0.

module tx_baud_generator
  #(parameter WIDTH_P = 32)
  (input  clk_i,
   input  reset_i,
   input [WIDTH_P-1:0] baud_div_i,
   output logic baud_o
   );

  wire load = reset_i || baud_o;
  logic [WIDTH_P-1:0] count_r;

  always_ff @(posedge clk_i) begin
    if (load) begin
      if (baud_div_i == 1) baud_o <= 1'b1;
      else baud_o <= 1'b0;

      count_r <= baud_div_i;
    end else begin
      count_r <= count_r - 1;
      baud_o <= (count_r == 2);
    end
  end

endmodule
