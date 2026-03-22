`timescale 1ns / 1ps

module detect_negedge
  (
    input logic clk_i,
    input logic reset_i,
    input logic sig_i,
    output logic negedge_o
  );

  logic sig_d, sig_q;
  assign sig_d = sig_i;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      sig_q <= 1'b0;
    end else begin
      sig_q <= sig_d;
    end
  end

  assign negedge_o = (sig_q && !sig_i);

endmodule
