`timescale 1ns/1ps

module fifo_fwft #(
  parameter int width_p = 8,
  parameter int depth_p = 32
) (
  input logic clk_i,
  input logic reset_i,
  // Write interface
  output logic ready_o,
  input logic valid_i,
  input logic [width_p-1:0] data_i,
  // Read interface
  input logic ready_i,
  output logic valid_o,
  output logic [width_p-1:0] data_o
);

  localparam int log2_depth_p = $clog2(depth_p);

  logic [log2_depth_p-1:0] ram_wr_addr;
  logic [log2_depth_p-1:0] ram_rd_addr;
  logic                    ram_full;
  logic                    ram_empty;
  logic [log2_depth_p:0]   ram_els_r, ram_els_n;
  logic                    ram_wr, ram_rd;

  always_comb begin
    ram_wr = valid_i && !ram_full;
    ram_rd = (!valid_o && !ram_empty) ||
             ((ready_i && valid_o) && !ram_empty);

    case({ram_wr, ram_rd})
      2'b10: ram_els_n = ram_els_r + 1;
      2'b01: ram_els_n = ram_els_r - 1;
      default: ram_els_n = ram_els_r;
    endcase
  end

  assign ready_o = !ram_full;

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      ram_els_r <= 0;
      ram_full <= 1'b1;
      ram_empty <= 1'b1;
      ram_wr_addr <= 0;
      ram_rd_addr <= 0;
      valid_o <= 1'b0;
    end else begin
      ram_els_r <= ram_els_n;
      ram_full <= (ram_els_n == depth_p);
      ram_empty <= (ram_els_n == 0);

      if (ram_rd) begin
        // assert valid_o if we ever read from the ram
        valid_o <= 1'b1;
      end else if (ready_i && valid_o) begin
        // deassert valid_oo if we don't read from ram and are passing out our data
        valid_o <= 1'b0;
      end

      if (ram_wr) ram_wr_addr <= ram_wr_addr + 1;
      if (ram_rd) ram_rd_addr <= ram_rd_addr + 1;
    end
  end

  ram_1r1w_sync #(
    .width_p(width_p),
    .depth_p(depth_p)
  ) ram (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .wr_en_i(ram_wr),
    .wr_addr_i(ram_wr_addr),
    .wr_data_i(data_i),
    .rd_en_i(ram_rd),
    .rd_addr_i(ram_rd_addr),
    .rd_data_o(data_o)
  );

endmodule
