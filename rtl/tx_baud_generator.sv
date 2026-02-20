`timescale 1ns / 1ps

module tx_baud_generator
  #(parameter WIDTH_P = 0)
  (input  clk_i,
   input  reset_i,
   input [WIDTH_P-1:0] baud_div_i,
   output logic baud_o
   );

  wire load = reset_i || baud_o;
  logic [WIDTH_P-1:0] count_r;

  always_ff @(posedge clk_i) begin
    if (load) begin
      count_r <= '0;
      baud_o <= (baud_div_i <= 1) ? 1'b1 : 1'b0;
    end else begin
      count_r <= count_r + 1;
      baud_o <= (count_r == (baud_div_i - 2));
    end
  end

endmodule
