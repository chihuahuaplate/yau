`timescale 1ns/1ps

`ifndef BINPATH
`define BINPATH ""
`endif

module ram_1r1w_sync #(
  parameter int width_p       = 8,
  parameter int depth_p       = 512,
  parameter string filename_p = "memory_init_file.bin"
) (
  input logic clk_i,
  input logic reset_i,
  // Write interface
  input logic wr_en_i,
  input logic [width_p-1:0] wr_data_i,
  input logic [$clog2(depth_p)-1:0] wr_addr_i,
  // Read interface
  input logic rd_en_i,
  input logic [$clog2(depth_p)-1:0] rd_addr_i,
  output logic [width_p-1:0] rd_data_o
);

  logic [width_p-1:0] mem_1r1w_sync [depth_p-1:0];

  // Simulation only
  initial begin
    $display("%m: depth_p is %d, width_p is %d", depth_p, width_p);
    $readmemb({`BINPATH, filename_p}, mem_1r1w_sync , 0, depth_p-1);
    for (int i = 0; i < depth_p; i++) begin
      $dumpvars(0, mem_1r1w_sync[i]);
    end
  end

  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      rd_data_o <= '0;
    end else begin
      if (rd_en_i) begin
        rd_data_o <= mem_1r1w_sync[rd_addr_i];
      end

      if (wr_en_i) begin
        mem_1r1w_sync[wr_addr_i] <= wr_data_i;
      end
    end
  end

endmodule
