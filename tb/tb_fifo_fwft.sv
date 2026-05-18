`timescale 1ns/1ps

module tb_fifo_fwft();

  // bench variables
  bit start;

  // bench params
  parameter clock_period_p = 10;
  parameter clock_unit_p   = -9;
  parameter reset_count_p  = 10;

  // bench time settings
  initial begin
    $timeformat(clock_unit_p, 2, "ns");
  end

  // bench clock & reset
  bit clk_i;
  bit reset_i, _reset_i, reset_li;
  assign reset_i = _reset_i || reset_li;

  nonsynth_clock_gen #(
    .CLOCK_PERIOD_P(clock_period_p)
  ) clock_gen (
    .clk_o(clk_i)
  );

  nonsynth_reset_gen #(
    .CLOCK_PERIOD_P(clock_period_p),
    .RESET_COUNT_P(reset_count_p)
  ) reset_gen (
    .clk_i(clk_i),
    .async_reset_o(_reset_i)
  );

  // dut params
  parameter int width_p = 8;
  parameter int depth_p = 16;

  // dut inputs
  logic               valid_i;
  logic [width_p-1:0] data_i;
  logic               ready_i;

  // dut outputs
  logic               ready_o;
  logic               valid_o;
  logic [width_p-1:0] data_o;

  // dut instance
  fifo_fwft #(
    .width_p(width_p),
    .depth_p(depth_p)
  ) DUT (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .ready_o(ready_o),
    .valid_i(valid_i),
    .data_i(data_i),
    .valid_o(valid_o),
    .data_o(data_o),
    .ready_i(ready_i)
  );

  // bench tasks
  task reset();
    reset_i = 1;
    @(negedge clk_i);
    reset_i = 0;
  endtask

  task push(
    input bit [7:0] data
  );
    valid_i = 1;
    data_i = data;
    @(negedge clk_i);
    valid_i = 0;
  endtask

  task pop();
    ready_i = 1;
    @(negedge clk_i);
    ready_i = 0;
  endtask

  task fill_test();
    repeat (depth_p+1) push($urandom());
  endtask

  task empty_test();
    // NOTE: must be full already
    assert(m_ready_o === 1'b0);
    repeat (depth_p+1) pop();
  endtask

  task fuzz_test();
    repeat (10000) begin
      if ($urandom_range(0, 1)) push($urandom());
      if ($urandom_range(0, 1)) pop();
    end
  endtask

  // reference model
  bit m_ready_o;
  bit m_valid_o;
  bit [width_p-1:0] m_data_o;
  int m_fifo_size_r;
  int m_fifo_size_n;

  bit [width_p-1:0] m_fifo_q [$];

  wire              m_push, m_pop;
  assign m_push = m_ready_o && valid_i;
  assign m_pop = m_valid_o && ready_i;

  always_comb begin
      case ({m_push, m_pop})
        2'b10: m_fifo_size_n <= m_fifo_size_r + 1;
        2'b01: m_fifo_size_n <= m_fifo_size_r - 1;
        default: m_fifo_size_n <= m_fifo_size_r;
      endcase
  end

  always @(posedge clk_i) begin
    if (reset_i) begin
      m_ready_o <= 0;
      m_valid_o <= 0;
      m_data_o <= 0;
      m_fifo_size_r <= 0;
      m_fifo_q.delete();
    end else begin
      m_fifo_size_r <= m_fifo_size_n;

      if (((m_fifo_size_r == depth_p) && (m_fifo_size_n == depth_p+1)) ||
          ((m_fifo_size_r == depth_p+1) && (m_fifo_size_n == depth_p+1))) begin
        m_ready_o <= 0;
      end else begin
        m_ready_o <= 1;
      end

      if ((m_fifo_size_r > 0) && (m_fifo_size_n != 0)) begin
        m_valid_o <= 1;
      end else begin
        m_valid_o <= 0;
      end

      // Push immediatley
      if (m_push) begin
        m_fifo_q.push_back(data_i);
        $display("[%0t] push data_i: %x", $time, data_i);
      end

      if ((m_fifo_size_r > 0) && (m_fifo_size_n != 0) && (!m_valid_o || m_pop)) begin
        $display("[%0t] pop data: %x", $time, m_fifo_q[0]);
        m_data_o <= m_fifo_q.pop_front();
      end
    end
  end

  // checker
  always @(posedge clk_i) begin
    if (start) begin

      // Check for X or Z's
      if ($isunknown(ready_o)) begin
        $fatal("[%0t] ready_o produced an unresolvable value.", $time);
      end
      if ($isunknown(valid_o)) begin
        $fatal("[%0t] valid_o produced an unresolvable value.", $time);
      end
      if ($isunknown(data_o)) begin
        $fatal("[%0t] data_o produced an unresolvable value.", $time);
      end

      // Check for valid values
      if (ready_o !== m_ready_o) begin
        $fatal("[%0t] DUT output & model mismatch: ready_o: (%b), m_ready_o (%b)",
               $time, ready_o, m_ready_o);
      end
      if (valid_o !== m_valid_o) begin
        $fatal("[%0t] DUT output & model mismatch: valid_o: (%b), m_valid_o (%b)",
               $time, valid_o, m_valid_o);
      end
      if (data_o !== m_data_o) begin
        $fatal("[%0t] DUT output & model mismatch: data_o: (%b), m_data_o (%b)",
               $time, data_o, m_data_o);
      end
    end
  end

  initial begin
    valid_i = 0;
    data_i = 0;
    ready_i = 0;

    @(negedge reset_i);
    @(negedge clk_i);
    $display("[%0t] Simulation start.", $time);
    start = 1;

    fill_test();
    empty_test();
    fuzz_test();

    $finish;
  end

endmodule
