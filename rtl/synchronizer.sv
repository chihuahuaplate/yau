`timescale 1ns/1ps

module synchronizer #(
  parameter int width_p = 2
) (
  input logic  clk_i,
  input logic  async_i,
  output logic sync_o
);
  (* ASYNC_REG = "TRUE" *)
  logic [width_p-1:0] sync_q = '1;

  assign sync_o = sync_q[width_p-1];

  always_ff @(posedge clk_i) begin
    sync_q <= {sync_q[width_p-2:0], async_i};
  end


endmodule
