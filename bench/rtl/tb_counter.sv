`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/19/2025 07:51:24 PM
// Design Name: 
// Module Name: tb_counter
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


module tb_counter();

   // params
   localparam width_p = 5;
   localparam [width_p-1:0] reset_val_p = '0;
   localparam               cycle_period_p = 10;
   localparam               GSR_DURATION = 100;

   // inputs
   reg                     reset_i, en_i, up_i, dw_i;
   
   // outputs
   wire [width_p-1:0]      count_o;
   

   // clock gen
   wire                    clk_i;
   nonsynth_clock_gen #(.cycle_period_p(cycle_period_p)) clk_gen (.clk_o(clk_i));
   
   // DUT
   counter
     #(.width_p(width_p)
      ,.reset_val_p(reset_val_p)
      )
   DUT
     (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(en_i)
     ,.up_i(up_i)
     ,.dw_i(dw_i)
     ,.count_o(count_o)
     );
   
   
   // tests
   initial begin
      reset_i = '0; en_i = '0; up_i = '0; dw_i = '0;
      #GSR_DURATION;
      reset_i = 1'b1; #100;
      reset_i = 1'b0; #100;

      // enable & increment
      en_i = 1'b1;
      for (int i = 1; i < $pow(2, width_p); i++) begin
         up_i = 1'b1; #cycle_period_p;
      end
      // clean-up
      up_i = 1'b0;
      
      // enable & decrement
      for (int i = 1; i < $pow(2, width_p); i++) begin
         dw_i = 1'b1; #cycle_period_p;
      end
      // clean-up
      dw_i = 1'b0;

      // disable & increment
      en_i = 1'b0;
      for (int i = 1; i < $pow(2, width_p); i++) begin
         up_i = 1'b1; #cycle_period_p;
      end
      // clean-up
      up_i = 1'b0;
      
            
      // disable & increment
      for (int i = 1; i < $pow(2, width_p); i++) begin
         dw_i = 1'b1; #cycle_period_p;
      end
      // clean-up
      dw_i = 1'b0;

      #1000;
   end
   
endmodule
