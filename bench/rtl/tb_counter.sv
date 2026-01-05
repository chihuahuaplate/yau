`timescale 1ns / 1ps

////////////////////////////////////////////
// Author: Carlos Rojas                   //
// File name: tb_counter.sv               //
// Purpose: Test bench for counter module //
////////////////////////////////////////////

module tb_counter();
  // params
  localparam WIDTH_P                      = 3;
  localparam [WIDTH_P-1:0] RESET_VAL_P    = '0;
  localparam               RESET_COUNT_P  = 2;
  localparam               CLOCK_PERIOD_P = 10;

  // inputs
  bit                      clk_i;

  // Set at start of sim by nonsynth_reset_gen
  bit                      _reset_i;
  // Use reset_li to set reset from procderal blocks
  bit                      reset_li;
  bit                      reset_i;
  assign reset_i = _reset_i | reset_li;

  bit tb_start; // 0 = not started/ 1 = started
  bit tb_error;

  // tasks

  // NOTE: tb_reset will reset for reset_count_i cycles.
  // reset rises relative to wherever the clock is on call. 
  task automatic tb_reset;
    input logic [31:0] reset_count_ti;
    
    reset_li = 1'b1;
    repeat (reset_count_ti) @(negedge clk_i);
    reset_li = 1'b0;
  endtask

  // inputs
  logic en_i, up_i, dw_i;

  // outputs
  wire [WIDTH_P-1:0] count_o;

  // clock gen
  nonsynth_clock_gen
    #(.CLOCK_PERIOD_P(CLOCK_PERIOD_P))
  clk_gen
    (.clk_o(clk_i));

  // reset gen
  nonsynth_reset_gen
    #(.CLOCK_PERIOD_P(CLOCK_PERIOD_P)
      ,.RESET_COUNT_P(RESET_COUNT_P)
      )
  reset_gen
    (.clk_i(clk_i)
     ,.async_reset_o(_reset_i)
     );

  // DUT
  counter
    #(.WIDTH_P(WIDTH_P)
      ,.RESET_VAL_P(RESET_VAL_P)
      )
  DUT
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(en_i)
     ,.up_i(up_i)
     ,.dw_i(dw_i)
     ,.count_o(count_o)
     );


  // input generator
  initial begin : input_generator
    // avoid X's at start of simulation
    reset_li          = 1'b0;
    en_i              = 1'b0;
    up_i              = 1'b0;
    dw_i              = 1'b0;

    @(negedge reset_i);

    repeat (2) @(negedge clk_i);

    $display("Simulation time is %0t", $time);
    $display("Input Generator, Start.");
    tb_start = 1;
    
    // Reset HIGH test, sweep other inputs
    reset_li          = 1'b1;
    en_i              = 1'b0;
    up_i              = 1'b0;
    dw_i              = 1'b0;
    for (int i = 0; i < $pow(2, 3); i++) begin
      {en_i, up_i, dw_i} = i[2:0];
      @(negedge clk_i);
    end
    
    tb_reset(RESET_COUNT_P);
    repeat (2) @(negedge clk_i);

    // Enable LOW test, sweep other inputs
    en_i              = 1'b0;
    up_i              = 1'b0;
    dw_i              = 1'b0;
    for (int i = 0; i < $pow(2, 2); i++) begin
      {up_i, dw_i} = i[1:0];
      @(negedge clk_i);
    end
    
    tb_reset(RESET_COUNT_P);
    repeat (2) @(negedge clk_i);
    
    // Enable HIGH test, sweep other inputs
    en_i              = 1'b1;
    up_i              = 1'b0;
    dw_i              = 1'b0;
    for (int i = 0; i < $pow(2, 2); i++) begin
      {up_i, dw_i} = i[1:0];
      @(negedge clk_i);
    end

    tb_reset(RESET_COUNT_P);
    repeat (2) @(negedge clk_i);

    // Test unresponsive counter inputs
    // up_i, dw_i = 00 or 11
    en_i = 1'b1;
    up_i = 1'b0;
    dw_i = 1'b0;

    repeat (2) @(negedge clk_i);
    
    up_i = 1'b1;
    dw_i = 1'b1;
    repeat (2) @(negedge clk_i);
    
    tb_reset(RESET_COUNT_P);
    repeat (2) @(negedge clk_i);

    // Test continuous up, no overflow
    assert (count_o === '0);
    en_i         = 1'b1;
    up_i = 1'b1;
    dw_i = 1'b0;
    
    repeat ($pow(2, WIDTH_P)-1) @(negedge clk_i);

    // Test continuous dw, no overflow
    assert (count_o === '1);
    en_i         = 1'b1;
    up_i = 1'b0;
    dw_i = 1'b1;
    
    repeat ($pow(2, WIDTH_P)-1) @(negedge clk_i);
    
    // Test underflow
    en_i         = 1'b1;
    up_i = 1'b0;
    dw_i = 1'b1;
    
    @(negedge clk_i);
    
    // Test overflow
    en_i         = 1'b1;
    up_i = 1'b1;
    dw_i = 1'b0;
    
    @(negedge clk_i);
        
    $finish();
  end

  // Golden model
  logic [WIDTH_P-1:0] count_tl;
  always @(posedge clk_i) begin : model
    if (reset_i) begin
      count_tl <= RESET_VAL_P;
    end else if (en_i) begin      
      count_tl <= count_tl + up_i - dw_i;
    end
  end

  // Checker
  always @(posedge clk_i) begin : output_checker
    if (tb_start) begin
      if ($isunknown(count_o)) begin
        $error("DUT produced unresolvable value.");
        tb_error = 1; #1;
        $finish();
      end else begin      
        if (count_o !== count_tl) begin
          $error("DUT output does not match model data. \
                DUT count_o: %b. Model output %b.",
                 count_o, count_tl
                 );
          tb_error = 1; #1;
          $finish();
        end
      end
    end
  end

  // This block executes after $finish() has been called.
  final begin
    $display("Simulation time is %0t", $time);
    if(tb_error) begin
      $display("    ______                    ");
      $display("   / ____/_____________  _____");
      $display("  / __/ / ___/ ___/ __ \\/ ___/");
      $display(" / /___/ /  / /  / /_/ / /    ");
      $display("/_____/_/  /_/   \\____/_/     ");
      $display("Simulation Failed");
    end else begin
      $display("    ____  ___   __________");
      $display("   / __ \\/   | / ___/ ___/");
      $display("  / /_/ / /| | \\__ \\\__ \ ");
      $display(" / ____/ ___ |___/ /__/ / ");
      $display("/_/   /_/  |_/____/____/  ");
      $display();
      $display("Simulation Succeeded!");
    end
  end

endmodule
