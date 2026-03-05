`timescale 1ns / 1ps

module tx_shift (
  input       clk_i,
  input       load_i,
  input [7:0] d_i,
  input       en_i,
  output      q_o
);

  logic [7:0] shift_r;

  always_ff @(posedge clk_i) begin
    if (load_i) begin
      shift_r <= d_i;
    end else if (en_i) begin
      shift_r <= {1'b1, shift_r[7:1]};
    end
  end

  assign q_o = shift_r[0];

endmodule
