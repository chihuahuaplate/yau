`timescale 1ns / 1ps

module nonsynth_reset_gen #(
  parameter CLOCK_PERIOD_P = 10,
  parameter RESET_COUNT_P = 10
) (
  input bit clk_i,
  output bit async_reset_o
);

  initial begin
    async_reset_o = 1;
    #(CLOCK_PERIOD_P*RESET_COUNT_P);
    @(negedge clk_i);
    async_reset_o = 0;
  end

endmodule
