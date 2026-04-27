`timescale 1ns / 1ps

module tb_detect_negedge();

  // params
  localparam CLOCK_PERIOD_LP = 10;
  localparam RESET_COUNT_LP = 10;

  // clock & resets
  bit clk_i;
  bit _reset_i;
  bit reset_li;
  bit reset_i;
  assign reset_i = _reset_i | reset_li;

  // clock & reset generator modules
  nonsynth_clock_gen #(
    .CLOCK_PERIOD_P(CLOCK_PERIOD_LP)
  ) clk_gen (
    .clk_o(clk_i)
  );

  nonsynth_reset_gen #(
    .CLOCK_PERIOD_P(CLOCK_PERIOD_LP),
    .RESET_COUNT_P(RESET_COUNT_LP)
  ) reset_gen (
    .clk_i(clk_i),
    .async_reset_o(_reset_i)
  );

  // inputs
  logic sig_i;

  // outpus
  logic negedge_o;

  // DUT
  detect_negedge DUT(
    .clk_i(clk_i),
    .reset_i(reset_i),
    .sig_i(sig_i),
    .negedge_o(negedge_o)
  );

  initial begin
    sig_i = 1'b0;

    @(negedge reset_i);

    sig_i = 1'b1;
    repeat (10) @(posedge clk_i);
    sig_i = 1'b0;
    repeat (10) @(posedge clk_i);

  end



endmodule
