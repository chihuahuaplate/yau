`timescale 1ns / 1ps

module tx_parity (
  input  clk_i,
  input  reset_i,
  input  en_i,
  input  bit_i,
  input  parity_type_i,
  output logic parity_o
);

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      parity_o <= !parity_type_i;
    end else if (en_i) begin
      parity_o <= parity_o ^ bit_i;
    end
  end


endmodule
