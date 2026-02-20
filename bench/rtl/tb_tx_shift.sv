`timescale 1ns / 1ps

module tb_tx_shift();

  // params
  localparam               RESET_COUNT_P  = 1;
  localparam               CLOCK_PERIOD_P = 10;
  
  // inputs
  bit                      clk_i;
  // Set at start of sim by nonsynth_reset_gen
  bit                      _reset_i;

  // Use reset_li to set reset from procderal blocks
  bit                      reset_li;
  bit                      reset_i;
  assign reset_i = _reset_i | reset_li;
  
  // clock gen
  nonsynth_clock_gen
    #(.CLOCK_PERIOD_P(CLOCK_PERIOD_P))
  clk_gen
    (.clk_o(clk_i)
     );

  // reset gen
  nonsynth_reset_gen
    #(.CLOCK_PERIOD_P(CLOCK_PERIOD_P)
      ,.RESET_COUNT_P(RESET_COUNT_P))
  reset_gen
    (.clk_i(clk_i)
     ,.async_reset_o(_reset_i)
     );

  // Inputs
  logic [7:0] d_i;
  logic       en_i;

  // Outputs
  logic       q_o;

  tx_shift DUT
    (.clk_i(clk_i),
     .load_i(reset_i),
     .d_i(d_i),
     .en_i(en_i),
     .q_o(q_o)
     );

  
  initial begin
    d_i = '0;
    en_i = 1'b0;
    
    @(negedge reset_i);
    repeat (2) @(negedge clk_i);
    
    $display();
    $display("Input Generator, Start.");    

    d_i = 8'b0101_0101;

    reset_li = 1'b1;
    repeat (RESET_COUNT_P) @(negedge clk_i);
    reset_li = 1'b0;
    
    @(negedge clk_i);
    
    en_i = 1'b1;

    repeat (8) @(negedge clk_i);

    $finish();
  end


endmodule
