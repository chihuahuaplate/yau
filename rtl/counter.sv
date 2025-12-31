`timescale 1ns / 1ps

// TODO: Include box comments

module counter
  #(parameter WIDTH_P = 8
   ,parameter [WIDTH_P-1:0] RESET_VAL_P = '0
    )
  (input clk_i
  ,input reset_i
  ,input en_i
  ,input up_i
  ,input dw_i
  ,output [WIDTH_P-1:0] count_o
   );

  
  logic [WIDTH_P-1:0] count_r, count_n;

  // Next state logic
  always_comb begin
    count_n = count_r;

    case ({up_i, dw_i})
      2'b01: count_n = count_n - 1;
      2'b10: count_n = count_n + 1;
      default: count_n = count_r;
    endcase
  end
  
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      count_r <= RESET_VAL_P;
    end
    else if (en_i) begin
      count_r <= count_n;
    end
  end

  // output assigns
  assign count_o = count_r;
  
endmodule
