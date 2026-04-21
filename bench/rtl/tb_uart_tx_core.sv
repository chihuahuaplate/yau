`timescale 1ns / 1ps

module tb_uart_tx_core();
  import uart_core_pkg::*;

  // bench variables
  bit error;

  // bench parameters
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

  // DUT parameter

  // DUT inputs
  logic [31:0] config_i;
  logic        valid_i;
  logic [7:0]  data_i;

  // DUT outputs
  logic       ready_o;
  logic       tx_o;

  // DUT instance
  uart_tx_core DUT (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .config_i(config_i),
    .ready_o(ready_o),
    .valid_i(valid_i),
    .data_i(data_i),
    .tx_o(tx_o)
  );

  // bench functions
  function int frequency_f;
    frequency_f = (1/(clock_period_p * $pow(10, clock_unit_p)));
  endfunction

  function int baud_div_f(
    input int baud_rate
  );
    // TODO: any overflow or underflow warnings?
    baud_div_f = frequency_f() / (16 * baud_rate);
  endfunction

  function bit parity_f(
    input parity_type_e parity_type,
    input data_width_e data_width,
    input logic [7:0] data
  );
    case (data_width)
      DW_5: parity_f = (parity_type == EVEN) ? (^data[4:0]) : !(^data[4:0]);
      DW_6: parity_f = (parity_type == EVEN) ? (^data[5:0]) : !(^data[5:0]);
      DW_7: parity_f = (parity_type == EVEN) ? (^data[6:0]) : !(^data[6:0]);
      DW_8: parity_f = (parity_type == EVEN) ? (^data[7:0]) : !(^data[7:0]);
    endcase
  endfunction

  // bench tasks
  task automatic reset;
    reset_li = 1;
    repeat (1) @(negedge clk_i);
    reset_li = 0;
  endtask

  task automatic configure(
    input int baud_rate,
    input data_width_e data_width,
    input parity_en_e parity_en,
    input parity_type_e parity_type,
    input stop_e stop
  );
    bit [26:0] baud_div;

    baud_div = baud_div_f(baud_rate);
    config_i = {baud_div, stop, parity_type, parity_en, data_width};
    @(posedge clk_i);
    $display("[%0t] Configuration change:", $time);
    $display ("Baud rate:   %0d", baud_rate);
    $display ("Baud div:    %0d", baud_div);
    $display ("Data width:  %0p", data_width);
    $display ("Parity en:   %0p", parity_en);
    $display ("Parity type: %0p", parity_type);
    $display ("Stop:        %0p", stop);
    @(negedge clk_i);
  endtask

  task automatic transmit(
    input logic [7:0] data
  );
    valid_i = 1;
    data_i = data;
    wait (wr_success == 1'b1);
    $display("[%0t] transmit started: data_i = %b", $time, data);
    @(negedge clk_i);
    valid_i = 0;
  endtask

  // input generator watchdog
  bit wr_success;
  int wr_timeout;

  always_ff @(posedge clk_i) begin
    wr_success <= ((ready_o === 1'b1) && valid_i);
  end

  always @(posedge clk_i) begin
    if (reset_i || ((ready_o === 1'b1) && valid_i)) begin
      wr_timeout <= 0;
    end else if (wr_timeout > 10) begin
      $error("[%0t] Timeout on ready_o. valid_i was high for 10 cycles with no response.", $time);
      error = 1; #1;
      $finish();
    end else if (valid_i && (ready_o !== 1'b1)) begin
      wr_timeout <= wr_timeout + 1;
    end
  end

  // behavioural model

  // behavioural model vars
  bit m_ready_o = 1'b1;
  bit m_tx_o = 1'b1;
  bit m_tx_active = 1'b0;

  bit m_tx_frame_q [$];
  int m_tx_frame_index;

  int m_tx_baud_count;
  int m_tx_baud_max;

  // behavioural model tasks

  task automatic prepare_frame(
    input logic [31:0] config_i,
    input logic [7:0] data_i
  );
    // Creates transmit frame (queue) and set other variables
    // for switching between the bits in the queue
    data_width_e data_width;
    parity_en_e parity_en;
    parity_type_e parity_type;
    stop_e stop;
    bit [26:0] baud_div;
    int data_len;

    data_width  = data_width_e'(config_i[1:0]);
    parity_en   = parity_en_e'(config_i[2]);
    parity_type = parity_type_e'(config_i[3]);
    stop        = stop_e'(config_i[4]);
    baud_div    = config_i[31:5];

    // clear queue & index
    m_tx_frame_q.delete();
    m_tx_frame_index <= 0;

    m_tx_baud_count <= 0;
    m_tx_baud_max = (baud_div << 4) - 1;

    // start bit
    m_tx_frame_q.push_back(1'b0);

    // data bits
    case (data_width)
      DW_5: data_len = 5;
      DW_6: data_len = 6;
      DW_7: data_len = 7;
      DW_8: data_len = 8;
    endcase

    for (int i = 0; i < data_len; i++) begin
      m_tx_frame_q.push_back(data_i[i]);
    end

    // parity bit
    if (parity_en == ENABLED) begin
      m_tx_frame_q.push_back(
        parity_f(parity_type, data_width, data_i)
      );
    end

    // stop bit(s)
    if (stop == ONE_STOP) begin
      m_tx_frame_q.push_back(1'b1);
    end else if (stop == TWO_STOP) begin
      m_tx_frame_q.push_back(1'b1);
      m_tx_frame_q.push_back(1'b1);
    end

    $display("[%0t] Model frame constructed: %p", $time, m_tx_frame_q);
  endtask

  always @(posedge clk_i) begin
    if (reset_i) begin
      m_ready_o <= 1'b1;
      m_tx_o <= 1'b1;
      m_tx_active <= 1'b0;
      m_tx_frame_q.delete();
      m_tx_frame_index <= 0;
      m_tx_baud_count <= 0;
      m_tx_baud_max = 0;
    end else if ($isunknown(ready_o)) begin
      $error("DUT produced unresolvable value on ready_o.");
      error = 1; #1;
      $finish();
    end else if ($isunknown(tx_o)) begin
      $error("DUT produced unresolvable value on tx_o.");
      error = 1; #1;
      $finish();
    end else begin

      if (!m_tx_active && (m_ready_o && valid_i)) begin
        m_tx_active <= 1'b1;
        m_ready_o <= 1'b0;
        prepare_frame(config_i, data_i);
      end else if (m_tx_active) begin
        m_tx_o <= m_tx_frame_q[m_tx_frame_index];

        // calculate frame index
        m_tx_baud_count <= m_tx_baud_count + 1;

        if (m_tx_baud_count == m_tx_baud_max) begin
          m_tx_baud_count <= 0;
          m_tx_frame_index <= m_tx_frame_index + 1;

          if (m_tx_frame_index == (m_tx_frame_q.size - 1)) begin
            m_tx_active <= 1'b0;
            m_ready_o <= 1'b1;
            m_tx_o <= 1'b1;
          end
        end
      end

      if (ready_o !== m_ready_o) begin
        $error("DUT output & Model mismatch: ready_o: (%b). m_ready_o (%b).",
               ready_o, m_ready_o);
        error = 1; #1;
        $finish();
      end

      if (tx_o !== m_tx_o) begin
        $error("DUT output & Model mismatch: tx_o: (%b). m_tx_o (%b).",
               tx_o, m_tx_o);
        error = 1; #1;
        $finish();
      end

    end
  end

  // input generator

  int baud_vectors [];
  int baud_rate;
  data_width_e data_width;
  parity_en_e parity_en;
  parity_type_e parity_type;
  stop_e stop;

  initial begin
    // default initial values
    config_i = '1;
    valid_i  = '0;
    data_i   = '0;

    baud_vectors = new [5];
    baud_vectors = '{4800, 9600, 19200, 38400, 57600, 115200};

    baud_rate = 0;
    data_width = DW_5;
    parity_en = DISABLED;
    parity_type = ODD;
    stop = ONE_STOP;

    @(negedge reset_i);
    repeat (10) @(negedge clk_i);

    $display("[%0t] Simulation start.", $time);

    for (int i = 0; i < baud_vectors.size(); i++) begin
      baud_rate = baud_vectors[i];
      // lood through data width
      data_width = data_width.first();
      do begin
        // loop through parity_en
        parity_en = parity_en.first();
        do begin
          // loop through parity_type
          parity_type = parity_type.first();
          do begin
            // loop through stop
            stop = stop.first();
            do begin
              data_i = $urandom();

              configure(baud_rate, data_width, parity_en, parity_type, stop);
              transmit(data_i);

              @(posedge m_ready_o);
              @(negedge clk_i);

              stop = stop.next();
            end while (stop != stop.first());
            parity_type = parity_type.next();
          end while (parity_type != parity_type.first());
          parity_en = parity_en.next();
        end while (parity_en != parity_en.first());
        data_width = data_width.next();
      end while (data_width != data_width.first());
    end

    $finish();
  end

  final begin
    if(error) begin
      $display("[0%t] Simulation Failed!", $time);
      $display("    ______                    ");
      $display("   / ____/_____________  _____");
      $display("  / __/ / ___/ ___/ __ \\/ ___/");
      $display(" / /___/ /  / /  / /_/ / /    ");
      $display("/_____/_/  /_/   \\____/_/    ");
    end else begin
      $display("[%0t] Simulation Succeeded!", $time);
      $display("    ____  ___   __________");
      $display("   / __ \\/   | / ___/ ___/");
      $display("  / /_/ / /| | \\__ \\\__\ ");
      $display(" / ____/ ___ |___/ /__/ /");
      $display("/_/   /_/  |_/____/____/");
    end
  end

endmodule
