`timescale 1ns / 1ps

module tb_tx_baud_generator();

  // NOTE: TIME_UNIT_P should be accurate to simulation simulation.
  // If `timescale 1ns / X, TIME_UNIT_P = -9
  // If `timescale 1us / X, TIME_UNIT_P = -6
  localparam               TIME_UNIT_P = -9;

  localparam               RESET_COUNT_P  = 2;
  localparam               CLOCK_PERIOD_P = 10;

  localparam               WIDTH_P = 27;
 
  bit                      clk_i;

  bit                      _reset_i;
  bit                      reset_li;
  bit                      reset_i;
  assign reset_i = _reset_i | reset_li;

  // clock generator
  nonsynth_clock_gen
    #(.CLOCK_PERIOD_P(CLOCK_PERIOD_P))
  clk_gen
    (.clk_o(clk_i)
     );

  // reset generatory
  nonsynth_reset_gen
    #(.CLOCK_PERIOD_P(CLOCK_PERIOD_P),
      .RESET_COUNT_P(RESET_COUNT_P))
  reset_gen
    (.clk_i(clk_i),
     .async_reset_o(_reset_i)
     );
  
  // inputs
  logic [WIDTH_P-1:0] baud_div_i;

  // outputs
  logic               baud_o;

  // DUT
  tx_baud_generator 
    #(.WIDTH_P(WIDTH_P))
  DUT
    (.clk_i(clk_i),
     .reset_i(reset_i),
     .baud_div_i(baud_div_i),
     .baud_o(baud_o)
     );

  function [WIDTH_P-1:0] baud_div_f;
    input int baud_rate;
    input int clock_period;
    input int time_unit;    

    baud_div_f = (1 / (clock_period * $pow(10, time_unit))) / (baud_rate);    

  endfunction


  initial begin
    baud_div_i = 1;


    @(negedge reset_i);
    repeat (2) @(negedge clk_i);

    // NOTE: ensure difference between baud pulses approximates the period of 
    // specified baud rate.


    // remain high
    baud_div_i = 1;
    repeat(baud_div_i*5) @(negedge clk_i);
    baud_div_i = baud_div_f(4800, CLOCK_PERIOD_P, TIME_UNIT_P);
    repeat(baud_div_i*5) @(negedge clk_i);
    baud_div_i = baud_div_f(9600, CLOCK_PERIOD_P, TIME_UNIT_P);
    repeat(baud_div_i*5) @(negedge clk_i);
    baud_div_i = baud_div_f(19200, CLOCK_PERIOD_P, TIME_UNIT_P);
    repeat(baud_div_i*5) @(negedge clk_i);
    baud_div_i = baud_div_f(38400, CLOCK_PERIOD_P, TIME_UNIT_P);
    repeat(baud_div_i*5) @(negedge clk_i);
    baud_div_i = baud_div_f(57600, CLOCK_PERIOD_P, TIME_UNIT_P);
    repeat(baud_div_i*5) @(negedge clk_i);
    baud_div_i = baud_div_f(115200, CLOCK_PERIOD_P, TIME_UNIT_P);
    repeat(baud_div_i*5) @(negedge clk_i);
  

    $finish();
  end
  


endmodule
