`timescale 1ns / 1ps

module tx_data_counter
  (input       clk_i,
   input       reset_i,
   input       en_i,
   input [1:0] data_width_i,
   output      data_done_o
   );

  logic [2:0] data_max_val;
  always_comb begin
    case(data_width_i)
      2'b00: data_max_val = 3'h4;
      2'b01: data_max_val = 3'h5;
      2'b10: data_max_val = 3'h6;
      2'b11: data_max_val = 3'h7;
    endcase
  end
    
  logic [2:0] count_r;
  
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      count_r <= '0;
    end else if (en_i) begin
      if (count_r == data_max_val) begin
        count_r <= '0;
      end 
    
      count_r <= count_r + 1;
    end
  end
  
  assign data_done_o = (count_r == data_max_val);

endmodule
