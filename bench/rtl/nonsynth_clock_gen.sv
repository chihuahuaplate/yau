`timescale 1ns / 1ps

module nonsynth_clock_gen #(
  parameter CLOCK_PERIOD_P = 10
) (
  output bit clk_o
);

  initial begin
    $display("%m with CLOCK_PERIOD_P ", CLOCK_PERIOD_P);
    assert(CLOCK_PERIOD_P >= 2) else $error("cannot simulate cycle time less than 2");
  end

  always begin
    #(CLOCK_PERIOD_P/2); clk_o = ~clk_o;
  end

endmodule
