`timescale 1ns / 1ps

module tb_uart_tx();

  // params
  localparam               RESET_COUNT_P  = 2;
  localparam               CLOCK_PERIOD_P = 10;
  localparam               DATA_BITS_5 = 2'b00;
  localparam               DATA_BITS_6 = 2'b01;
  localparam               DATA_BITS_7 = 2'b10;
  localparam               DATA_BITS_8 = 2'b11;

  // clock & resets
  bit                      clk_i;

  bit                      _reset_i;
  bit                      reset_li;
  bit                      reset_i;
  assign reset_i = _reset_i | reset_li;

  // inputs
  logic [31:0] config_i;
  logic [7:0]  data_i;
  logic        valid_i;
  
  // outputs
  logic         ready_o;
  logic         tx_o;

  // clock generator
  nonsynth_clock_gen #(.CLOCK_PERIOD_P(CLOCK_PERIOD_P))
  clk_gen
    (.clk_o(clk_i));

  // reset generator
  nonsynth_reset_gen
    #(.CLOCK_PERIOD_P(CLOCK_PERIOD_P)
     ,.RESET_COUNT_P(RESET_COUNT_P))
  reset_gen
    (.clk_i(clk_i)
    ,.async_reset_o(_reset_i)
    );

  // DUT
  uart_tx DUT
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.config_i(config_i)
    ,.data_i(data_i)
    ,.valid_i(valid_i)
    ,.ready_o(ready_o)
    ,.tx_o(tx_o)
    );


  function [31:0] configure_f;
    input logic [1:0] data_width;
    input logic       parity;
    input logic       parity_type;
    input logic       extra_stop;
    input int         baud_rate;
    
    logic [26:0] baud_div;
    
    begin
      baud_div = (1/(CLOCK_PERIOD_P * $pow(10, -9)))/baud_rate;
      configure_f = {baud_div, extra_stop, parity_type, parity, data_width};
    end

  endfunction

  initial begin
    config_i = configure_f(DATA_BITS_8, 0, 0, 0, 115200);
    data_i = $random();
    valid_i = 1'b0;

    @(negedge reset_i);
    repeat (2) @(negedge clk_i);
    
    $display("Simulation time is %0t", $time);
    $display("Input Generator, Start.");
    
    valid_i = 1'b1;
    @(negedge clk_i);
    valid_i = 1'b0;
    
    repeat (100000000) @(negedge clk_i);

    $finish();
  end


endmodule

