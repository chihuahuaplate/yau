`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 12/19/2025 08:44:18 PM
// Design Name:
// Module Name: shift
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


module shift
  #(parameter width_p = 8
   ,parameter [width_p-1:0] reset_val_p = '0
   )
   (input wire clk_i
   ,input wire reset_i
   ,input wire en_i
   ,input wire serial_i

   ,input wire load_i
   ,input wire [width_p-1:0] parallel_i

   ,output wire [width_p-1:0] parallel_o
   ,output wire serial_o
   );

   logic [width_p-1:0] shift_r;

   always_ff @(posedge clk_i) begin
      if (reset_i) begin
         shift_r <= reset_val_p;
      end
      else begin
         if (load_i) begin
            shift_r <= parallel_i;
         end
         else if (en_i) begin
            shift_r <= {shift_r[width_p-2:0], serial_i};
         end
      end
   end

   assign parallel_o = shift_r;
   assign serial_o = shift_r[width_p-1];
endmodule
