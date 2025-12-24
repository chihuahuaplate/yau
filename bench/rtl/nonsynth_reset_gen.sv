`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/21/2025 05:42:05 PM
// Design Name: 
// Module Name: nonsynth_reset_gen
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module nonsynth_reset_gen
  #(parameter clock_period_p = 10
   ,parameter reset_count_p = 10
    )
   (input bit clk_i
    ,output bit reset_o
    );
   
   initial begin
      $display("%m with reset_count_p", reset_count_p);
      assert(reset_count_p >= 1)
        else $error("cannot reset with reset count less than 1");
   end

   initial begin
      reset_o = 1;
      #(clock_period_p*reset_count_p);
      @(posedge clk_i);
      reset_o = 0;
   end

endmodule