`timescale 1ns / 1ps


module nonsynth_clock_gen
  #(parameter clock_period_p = 10)
   (output bit clk_o);

    // NOTE: bit data type causes clk_o to take on only values 0 or 1.
    // If uninitialized, defaults to value of 0

   initial begin
      $display("%m with clock_period_p ", clock_period_p);
      assert(clock_period_p >= 2)
	    else $error("cannot simulate cycle time less than 2");      
   end
   
   always begin
      #(clock_period_p/2); clk_o = ~clk_o;
   end

endmodule
