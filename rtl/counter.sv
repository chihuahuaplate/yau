`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/18/2025 02:34:59 PM
// Design Name: 
// Module Name: counter
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


module counter
  #(parameter width_p = 8
   ,parameter [width_p-1:0] reset_val_p = '0
   )
   (input wire clk_i
   ,input wire reset_i
   ,input wire en_i
   ,input wire up_i
   ,input wire dw_i
   ,output wire [width_p-1:0] count_o
   );
   
   logic [width_p-1:0] count_r;
   
   always_ff @(posedge clk_i) begin
    if (reset_i) begin
        count_r <= reset_val_p;
    end
    else begin
        if (en_i) begin
            if (up_i && (up_i ^ dw_i))
                count_r <= count_r + 1;
            else if (dw_i && (up_i ^ dw_i))
                count_r <= count_r - 1;
        end
      end
   end

   assign count_o = count_r;
   
endmodule
