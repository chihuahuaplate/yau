`timescale 1ns / 1ps

module tb_tx_data_counter();

  // params
  localparam               RESET_COUNT_P  = 1;
  localparam               CLOCK_PERIOD_P = 10;

  localparam               DATA_BITS_5 = 2'b00;
  localparam               DATA_BITS_6 = 2'b01;
  localparam               DATA_BITS_7 = 2'b10;
  localparam               DATA_BITS_8 = 2'b11;  
  
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
  logic en_i;
  logic [1:0] data_width_i;

  // Outputs
  logic       data_done_o;

  // DUT
  tx_data_counter DUT
    (.clk_i(clk_i),
     .reset_i(reset_i),
     .en_i(en_i),
     .data_width_i(data_width_i),
     .data_done_o(data_done_o)
     );

  task automatic RESET_TASK();
    reset_li = 1'b1;
    repeat (RESET_COUNT_P) @(negedge clk_i);
    reset_li = 1'b0;
  endtask


  initial begin
    en_i = 1'b0;
    data_width_i = DATA_BITS_5;

    @(negedge clk_i);
    repeat (2) @(negedge clk_i);

    en_i = 1'b1;
    repeat (5) @(negedge clk_i);
    
    RESET_TASK();

    data_width_i = DATA_BITS_6;
    repeat (6) @(negedge clk_i);

    RESET_TASK();

    data_width_i = DATA_BITS_7;
    repeat (7) @(negedge clk_i);

    RESET_TASK();

    data_width_i = DATA_BITS_8;
    repeat (8) @(negedge clk_i);

    $finish();
  end

endmodule
