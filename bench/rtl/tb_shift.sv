`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:
// Engineer:
//
// Create Date: 12/19/2025 09:06:19 PM
// Design Name:
// Module Name: tb_shift
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

module tb_shift();

   // params
   localparam width_p = 8;
   localparam [width_p-1:0] reset_val_p = '0;
   localparam               clock_period_p = 10;
   localparam               reset_count_p = 10;
   localparam               GSR_DURATION = 100;

   // inputs
   wire                     clk_i; // Driven by nonsynth_clock_gen
   reg                      reset_i;
   reg                      en_i;
   reg                      serial_i;
   
   reg                      load_i;
   reg [width_p-1:0]        parallel_i;

   // outputs
   wire [width_p-1:0]       parallel_o;
   wire                     serial_o;

   // clock gen
   nonsynth_clock_gen
     #(.clock_period_p(clock_period_p))
   clk_gen
     (.clk_o(clk_i));

   // DUT
   shift
     #(.width_p(width_p)
       ,.reset_val_p(reset_val_p)
       )
   DUT
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.en_i(en_i)
      ,.serial_i(serial_i)
      ,.load_i(load_i)
      ,.parallel_i(parallel_i)
      ,.parallel_o(parallel_o)
      ,.serial_o(serial_o)
      );

   // tb variables
   reg error_o;
   initial error_o = 0;
   
   reg [width_p-1:0] shift_expected;
   initial shift_expected = '0;
   
   // tests
   initial begin
      reset_i = 1;
      en_i = 0;
      serial_i = 0;
      load_i = 0;
      parallel_i = '0;      
      #GSR_DURATION;

      // Initial design reset
      repeat (reset_count_p) #clock_period_p;
      @(negedge clk_i); reset_i = 0; // NOTE: Assignments synced to negedge
      repeat (reset_count_p) #clock_period_p;


      $display("Out of reset sequence at time: %t", $time);
      $display("Beginning tests now.");
      
      // NOTE: while reset_i high, output should take on reset_val_p
      // Other inputs should not effect the DUT.
      
      reset_i = 1;

      for(int i = 0; i < $pow(2, width_p + 3); i++) begin
         en_i = i[width_p+2];
         serial_i = i[width_p+1];
         load_i = i[width_p];
         parallel_i = i[width_p-1:0];
         #clock_period_p;
         
         if (parallel_o != reset_val_p) begin
            $display("ERROR: At time: %t ---- parallel_o != reset_val_p", $time);
            $display("parallel_o != reset_val_p ---- %b != %b", parallel_o, reset_val_p);
            error_o = 1;
            $finish();
         end

         if (serial_o != parallel_o[width_p-1]) begin
            $display("ERROR: At time: %t ---- serial_o != parallel_o[%d-1]", $time, width_p);
            $display("serial_o != parallel_o[%d-1] ---- %b != %b", width_p, serial_o, parallel_o[width_p-1]);
            error_o = 1;
            $finish();
         end
      end
      
      reset_i = 0;
      
      // NOTE: While reset_i low & load_i is high, parallel_o should take on value
      // of parallel_i.
      
      load_i = 1;
      
      for(int i = 0; i < $pow(2, width_p+2); i++) begin
         en_i = i[width_p+1];
         serial_i = i[width_p];
         parallel_i = i[width_p-1:0];
         #clock_period_p;
         
         if (parallel_o != parallel_i) begin
            $display("ERROR: At time: %t ---- parallel_o != parallel_i", $time);
            $display("parallel_o != parallel_i ---- %b != %b", parallel_o, parallel_i);
            error_o = 1;
            $finish();
         end

         if (serial_o != parallel_o[width_p-1]) begin
            $display("ERROR: At time: %t ---- serial_o != parallel_o[%d-1]", $time, width_p);
            $display("serial_o != parallel_o[%d-1] ---- %b != %b", width_p, serial_o, parallel_o[width_p-1]);
            error_o = 1;
            $finish();
         end
      end
      
      // NOTE: While reset_i LOW & load_i LOW & en_i HIGH, should shift out data, For this test,
      // let's load in known value of all 1's (keep load_i high)
      
      parallel_i = '1;
      shift_expected = '1;
      #clock_period_p;
      
      load_i = 0;
      en_i = 1;
      serial_i = 1;


      // start with known parallel_o = '1;
      // we toggle serial_i between 0 and 1
      // with init value being 0
      // If we run the shifter width_p clock cycles we will have a known pattern
      // cycle 0: serial_i = 0, parallel_o = {width_p-1'b1, 0}
      // cycle 1: serial_i = 1, parallel_o = {width_p-2'b1, 0, 1}
      // and so on ....
      // If serial_i = 0, then parallel_o is a left shift by 1.
      // If serial_i = 1, then parallel_o is a left shift by 1 THEN add by 1.
      // expected result carried in shift_expected register

      for (int i = 0; i < (2*width_p); i++) begin
         serial_i = ~serial_i;  // Toggle serial_i
         shift_expected = serial_i ? ((shift_expected << 1) + 1) : (shift_expected << 1);

         #clock_period_p;

         if (parallel_o != shift_expected) begin
            $display("ERROR: At time: %t ---- parallel_o != shift_expected", $time);
            $display("parallel_o != shift_expected ---- %b != %b", parallel_o, shift_expected);
            error_o = 1;
            $finish();
         end

         if (serial_o != shift_expected[width_p-1]) begin
            $display("ERROR: At time: %t ---- serial_o != shift_expected[%d]", $time, width_p-1);
            $display("serial_o != shift_expected[%d] ---- %b != %b", width_p-1, serial_o, shift_expected[width_p-1]);
            error_o = 1;
            $finish();
         end
      end
      
      $finish();
   end

   final begin
      $display("Simulation ended at time: %t", $time);
      if (error_o) begin
         $display("Simulation results: FAIL");
      end
      else begin
         $display("Simulation results: PASS");
      end
   end

endmodule
