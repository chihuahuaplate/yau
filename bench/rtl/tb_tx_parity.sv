`timescale 1ns / 1ps

module tb_tx_parity();
  // bench vars
  bit error_o;
  bit [3:0] tb_vec;

  // params
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
  logic parity_type_i;
  logic bit_i;
  
  // Outputs
  logic  parity_o;

  tx_parity DUT
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.en_i(en_i)
    ,.parity_type_i(parity_type_i)
    ,.bit_i(bit_i)
    ,.parity_o(parity_o)
    );
  
  initial begin
    en_i   = 1'b0;
    parity_type_i = 1'b0;
    bit_i    = 1'b0;
    
    @(negedge reset_i);

    repeat (2) @(negedge clk_i);

    $display();
    $display("Input Generator, Start.");    

    // Enable DUT
    en_i   = 1'b1;
    // Odd parity
    parity_type_i = 1'b0;
    
    tb_vec = '0;
    do begin
      for (int i = 0; i < $size(tb_vec); i++) begin
        bit_i = tb_vec[i];
        @(negedge clk_i);
      end
      
      tb_vec = tb_vec + 1;
    end while (tb_vec !== '0);

    // Reset between tests
    reset_li            = 1'b1;
    repeat (RESET_COUNT_P) @(negedge clk_i);
    reset_li            = 1'b0;    
    
    // Even parity
    parity_type_i              = 1'b1;
    tb_vec              = '0;
    
    do begin
      for (int i = 0; i < $size(tb_vec); i++) begin
        bit_i = tb_vec[i];
        @(negedge clk_i);
      end
      
      tb_vec = tb_vec + 1;
    end while (tb_vec !== '0);
    
    
    $finish();
  end // initial begin
  

  // Behavioural model
  logic parity_tl;
  always @(posedge clk_i) begin
    if (reset_i) begin
      parity_tl <= 1'b0;
    end else if ($isunknown(parity_o)) begin
      $error("DUT produced unresolvable: parity_o = X");
      error_o = 1; #1;
      $finish();
    end else begin

      if (en_i) begin
        parity_tl <= (parity_type_i) ? (parity_tl ~^ bit_i)
                                     : (parity_tl ^ bit_i);
      end

      if (parity_o !== parity_tl) begin
        $error("DUT output does not match model output.");
        $display("DUT parity_o: (%b). Model output: (%b).\nParity type: (%b).\ntb_vec: (%b).",
                parity_o, parity_tl, parity_type_i, tb_vec);
        error_o = 1; #1;
        $finish();
      end
    end
  end // always @ (posedge clk_i)

  

  final begin
    $display("Simulation time is %0t", $time);
    if(error_o) begin
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
