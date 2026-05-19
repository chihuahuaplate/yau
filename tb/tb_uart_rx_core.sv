`timescale 1ns / 1ps

module tb_uart_rx_core();
  import uart_core_pkg::*;

  // bench variables
  bit error;

  // bench types
  typedef enum bit [0:0] {
    FALSE_START,
    TRUE_START
  } start_type_e;

  typedef enum bit [0:0] {
    FALSE_START_EARLY,
    FALSE_START_LATE
  } false_timing_e;

  typedef enum bit [0:0] {
    FRAME_ERROR_TRUE,
    FRAME_ERROR_FALSE
  } frame_error_e;

  typedef enum bit [0:0] {
    PARITY_ERROR_TRUE,
    PARITY_ERROR_FALSE
  } parity_error_e;

  typedef enum bit [0:0] {
    OVERRUN_ERROR_TRUE,
    OVERRUN_ERROR_FALSE
  } overrun_error_e;

  // bench parameters
  parameter clock_period_p = 10;
  parameter clock_unit_p   = -9;
  parameter reset_count_p  = 10;

  // bench time settings
  initial begin
    $timeformat(clock_unit_p, 2, "ns");
  end

  // bench clock & resets
  bit clk_i;
  bit reset_i, _reset_i, reset_li;
  assign reset_i = _reset_i | reset_li;

  nonsynth_clock_gen #(
    .CLOCK_PERIOD_P(clock_period_p)
  ) clk_gen (
    .clk_o(clk_i)
  );

  nonsynth_reset_gen #(
    .CLOCK_PERIOD_P(clock_period_p),
    .RESET_COUNT_P(reset_count_p)
  ) reset_gen (
    .clk_i(clk_i),
    .async_reset_o(_reset_i)
  );

  // DUT inputs
  logic [31:0] config_i;
  logic rx_i;
  logic ready_i;

  // DUT outputs
  logic valid_o;
  logic [7:0] data_o;
  logic frame_error_o;
  logic parity_error_o;
  logic overrun_error_o;

  // DUT instance
  uart_rx_core DUT (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .config_i(config_i),
    .rx_i(rx_i),
    .ready_i(ready_i),
    .valid_o(valid_o),
    .data_o(data_o),
    .frame_error_o(frame_error_o),
    .parity_error_o(parity_error_o),
    .overrun_error_o(overrun_error_o)
  );

  // bench functions
  function int frequency_f;
    frequency_f = (1/(clock_period_p * $pow(10, clock_unit_p)));
  endfunction

  function int baud_div_f(
    input int baud_rate
  );
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

  function int data_len_f(
    input data_width_e data_width
  );
    case (data_width)
      DW_5: data_len_f = 5;
      DW_6: data_len_f = 6;
      DW_7: data_len_f = 7;
      DW_8: data_len_f = 8;
    endcase
  endfunction

  // bench tasks
  task reset;
    reset_li = 1;
    repeat (1) @(negedge clk_i);
    reset_li = 0;
  endtask

  task configure(
    input int baud_rate,
    input data_width_e data_width,
    input parity_en_e parity_en,
    input parity_type_e parity_type,
    input stop_e stop
  );
    bit [26:0] baud_div;

    baud_div = baud_div_f(baud_rate);
    config_i = {baud_div, stop, parity_type, parity_en, data_width};
    $write("[%0t] Config change: ", $time());
    $write("Baud_rate: %0d, Baud_div: %0d, Data_width: %p, Parity_en: %p, Parity_type: %p, Stop: %p",
           baud_rate, baud_div, data_width, parity_en, parity_type, stop
    );
    $display();
    @(negedge clk_i);
  endtask

  // Transmitter
  bit tx_start;
  bit tx_frame_q [$];
  int tx_frame_index;
  int tx_baud_count;
  int tx_baud_max;
  start_type_e tx_start_type;
  false_timing_e tx_false_timing;
  bit tx_active;
  bit tx_o;

  task automatic transmit(
    input logic [7:0] data,
    input data_width_e data_width,
    input parity_en_e parity_en,
    input parity_type_e parity_type,
    input stop_e stop,
    input start_type_e start_type,
    input false_timing_e false_timing,
    input frame_error_e frame_error,
    input parity_error_e parity_error
  );
    // This task creates the Queue which the TX procedure will source to produce tx_o,
    // sets up variables for changing between queue elements to occur in a timley
    // manner and will insert cause errors on the output such as false starts, frame errors
    // or parity errors.

    tx_frame_q.delete();
    tx_frame_index <= 0;
    tx_baud_count <= 0;
    tx_baud_max = (config_i[31:5] << 4) - 1;

    // Used in the TX procedure to set START bit back to HIGH either immediatley after going low or late,
    // which is one cycle before the sampling of the start bit.
    tx_start_type = start_type;
    tx_false_timing = false_timing;

    // start bit
    tx_frame_q.push_back(1'b0);

    // data bits
    for (int i = 0; i < data_len_f(data_width); i++) begin
      tx_frame_q.push_back(data[i]);
    end

    // parity bit

    if (parity_en == ENABLED) begin
      if (parity_error == PARITY_ERROR_TRUE) begin
        tx_frame_q.push_back(!parity_f(parity_type, data_width, data));
      end else begin
        tx_frame_q.push_back(parity_f(parity_type, data_width, data));
      end
    end

    // stop bit(s)
    if (stop == ONE_STOP) begin
      if (frame_error == FRAME_ERROR_TRUE) begin
        tx_frame_q.push_back(1'b0);
      end else begin
        tx_frame_q.push_back(1'b1);
      end
    end else if (stop == TWO_STOP) begin
      // Frame error on first stop bit
      if (frame_error == FRAME_ERROR_TRUE) begin
        if ($urandom_range(1, 0) == 0) begin
          tx_frame_q.push_back(1'b0);
          tx_frame_q.push_back(1'b1);
        end else begin
          tx_frame_q.push_back(1'b1);
          tx_frame_q.push_back(1'b0);
        end
      end else begin
        tx_frame_q.push_back(1'b1);
        tx_frame_q.push_back(1'b1);
      end
    end

    // Signals TX procedure to start if not active
    tx_start = 1;
    @(negedge clk_i);
    tx_start = 0;
  endtask

  // TX procedure
  always @(posedge clk_i) begin
    if (reset_i) begin
      tx_frame_q.delete();
      tx_frame_index <= 0;
      tx_baud_count <= 0;
      tx_baud_max = 0;
      tx_start_type = TRUE_START;
      tx_false_timing = FALSE_START_EARLY;
      tx_active <= 0;
      tx_o <= 1;
    end else if (!tx_active && tx_start) begin
      tx_active <= 1;
    end else if (tx_active) begin
      tx_o <= tx_frame_q[tx_frame_index];

      if (tx_start_type == FALSE_START) begin
        if (tx_false_timing == FALSE_START_EARLY) begin
          if (tx_frame_index == 0 && (tx_baud_count > 0)) begin
            tx_o <= 1;
          end
        end else begin
          // LATE false start
          if (tx_frame_index == 0 && (tx_baud_count == ((config_i[31:5] * 8)))) begin
            tx_o <= 1;
          end
        end
      end

      tx_baud_count <= tx_baud_count + 1;
      if (tx_baud_count == tx_baud_max) begin
        tx_baud_count <= 0;
        tx_frame_index <= tx_frame_index + 1;

        if (tx_frame_index == (tx_frame_q.size() - 1)) begin
          tx_active <= 0;
          tx_o <= 1;
        end
      end
    end
  end

  // Behavioural model
  bit rx_negedge;
  detect_negedge rx_detect_negedge (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .sig_i(rx_i),
    .negedge_o(rx_negedge)
  );

  bit rx_active;
  bit rx_frame_q [$];
  int rx_baud_count;
  int rx_baud_max;
  int rx_sample_count;
  bit rx_sample_start_bit;
  bit rx_false_start;
  bit [7:0] rx_frame_data;

  // Outputs
  bit rx_valid_o;
  bit [7:0] rx_data_o;
  bit rx_frame_error_o;
  bit rx_parity_error_o;
  bit rx_overrun_error_o;

  always @(posedge clk_i) begin
    if (reset_i) begin
      rx_overrun_error_o <= 0;
    end else if ($isunknown(overrun_error_o)) begin
      $error("DUT produced unresolvable value on overrun_error_o.");
      error = 1; #1;
      $finish;
    end else begin
      if (rx_overrun_error_o == 1'b1) begin
        rx_overrun_error_o <= 0;
      end else if (rx_valid_o && !ready_i) begin
        rx_overrun_error_o <= 1;
      end

      if (overrun_error_o !== rx_overrun_error_o) begin
        $error("DUT output mismatch: overrun_error_o: (%b). rx_overrun_error_o: (%b)",
               overrun_error_o, rx_overrun_error_o);
        error = 1; #1;
        $finish;
      end

    end
  end

  always @(posedge clk_i) begin
    if (reset_i) begin
      rx_active <= 0;
      rx_frame_q.delete();
      rx_baud_count <= 0;
      rx_baud_max = 0;
      rx_sample_count <= 0;
      rx_sample_start_bit <= 1;
      rx_false_start <= 0;
      rx_frame_data = 0;

      rx_valid_o <= 0;
      rx_data_o <= 0;
      rx_frame_error_o <= 0;
      rx_parity_error_o <= 0;
    end else if ($isunknown(valid_o)) begin
      $error("DUT produced unresolvable value on valid_o.");
      error = 1; #1;
      $finish;
    end else if ($isunknown(data_o)) begin
      $error("DUT produced unresolvable value on data_o.");
      error = 1; #1;
      $finish;
    end else if ($isunknown(frame_error_o)) begin
      $error("DUT produced unresolvable value on frame_error_o.");
      error = 1; #1;
      $finish;
    end else if ($isunknown(parity_error_o)) begin
      $error("DUT produced unresolvable value on parity_error_o.");
      error = 1; #1;
      $finish;
    end else begin

      if (!rx_active) begin
        rx_valid_o <= 0;
        rx_frame_error_o <= 0;
        rx_parity_error_o <= 0;

        if (rx_false_start) begin
          rx_false_start <= 0;
        end else if (rx_negedge) begin
          rx_active <= 1;
          rx_frame_q.delete();
          rx_baud_count <= 0;
          rx_baud_max = config_i[31:5] - 1;
          rx_sample_count <= 0;
          rx_sample_start_bit <= 1;

          rx_frame_data = 0;
          rx_data_o <= 0;
        end
      end else begin
        rx_baud_count <= rx_baud_count + 1;

        if (rx_baud_count == rx_baud_max) begin
          rx_baud_count <= 0;
          rx_sample_count <= rx_sample_count + 1;

          if (rx_sample_start_bit && (rx_sample_count == 7)) begin
            // $display("[%0t] Sample start bit", $time());
            rx_sample_start_bit <= 0;
            rx_sample_count <= 0;
            rx_frame_q.push_back(rx_i);

            if (rx_i == 1) begin
              rx_false_start <= 1;
              rx_active <= 0;
            end
          end else if (!rx_sample_start_bit && (rx_sample_count == 15)) begin
            // $display("[%0t] Sample bit", $time());
            rx_sample_count <= 0;
            rx_frame_q.push_back(rx_i);

            if (rx_frame_q.size() == tx_frame_q.size()) begin
              rx_active <= 0;
              // outputs
              rx_valid_o <= 1;

              for (int i = 0; i < data_len_f(data_width); i++) begin
                rx_frame_data[i] = rx_frame_q[i+1];
              end
              rx_data_o <= rx_frame_data;

              if (stop == ONE_STOP) begin
                rx_frame_error_o <= rx_frame_q[rx_frame_q.size() - 1] != 1;
              end else begin
                rx_frame_error_o <= (rx_frame_q[rx_frame_q.size() - 1] != 1) ||
                                    (rx_frame_q[rx_frame_q.size() - 2] != 1);
              end

              if (parity_en == ENABLED) begin
                rx_parity_error_o <= rx_frame_q[data_len_f(data_width)+1] !=
                                     parity_f(parity_type, data_width, rx_frame_data);
              end

            end
          end
        end
      end

      if (valid_o !== rx_valid_o) begin
        $error("DUT output mismatch: valid_o: (%b). rx_valid_o: (%b)",
               valid_o, rx_valid_o);
        error = 1; #1;
        $finish;
      end

      if (rx_valid_o) begin

        if (data_o !== rx_data_o) begin
          $error("DUT output mismatch: data_o: (%b). rx_data_o: (%b)",
                 data_o, rx_data_o);
          error = 1; #1;
          $finish;
        end

        if (frame_error_o !== rx_frame_error_o) begin
          $error("DUT output mismatch: frame_error_o: (%b). rx_frame_error_o: (%b)",
                 frame_error_o, rx_frame_error_o);
          error = 1; #1;
          $finish;
        end

        if (parity_error_o !== rx_parity_error_o) begin
          $error("DUT output mismatch: parity_error_o: (%b). rx_parity_error_o: (%b)",
                 parity_error_o, rx_parity_error_o);
          error = 1; #1;
          $finish;
        end
      end
    end
  end

  // Input generator
  int baud_array [4] = '{19200, 38400, 57600, 115200};
  int baud_rate;
  data_width_e data_width;
  parity_en_e parity_en;
  parity_type_e parity_type;
  stop_e stop;
  start_type_e start_type;
  false_timing_e false_timing;
  frame_error_e frame_error;
  parity_error_e parity_error;
  overrun_error_e overrun_error;

  assign rx_i = tx_o;
  assign ready_i = (overrun_error == OVERRUN_ERROR_TRUE) ? 1'b0: 1'b1;

  initial begin
    // default values, avoid X's at start of simulation
    config_i = '0;

    baud_rate = 115200;
    data_width = DW_8;
    parity_en = ENABLED;
    parity_type = ODD;
    stop = TWO_STOP;
    start_type = FALSE_START;
    false_timing = FALSE_START_LATE;
    frame_error = FRAME_ERROR_FALSE;
    parity_error = PARITY_ERROR_FALSE;
    overrun_error = OVERRUN_ERROR_FALSE;

    @(negedge reset_i);
    repeat (10) @(negedge clk_i);

    $display("[%0t] Simulation start.", $time);

    for (int i = 0; i < 4; i++) begin
      baud_rate = baud_array[i];

      data_width = data_width.first();
      do begin

        parity_en = parity_en.first();
        do begin

          parity_type = parity_type.first();
          do begin

            stop = stop.first();
            do begin

              start_type = start_type.first();
              do begin

                false_timing = false_timing.first();
                do begin

                  frame_error = frame_error.first();
                  do begin

                    parity_error = parity_error.first();
                    do begin

                      overrun_error = overrun_error.first();
                      do begin

                        configure(baud_rate, data_width, parity_en, parity_type, stop);
                        transmit($urandom, data_width, parity_en, parity_type, stop, start_type, false_timing, frame_error, parity_error);

                        @(negedge tx_active);
                        repeat (10) @(negedge clk_i);

                        overrun_error = overrun_error.next();
                      end while (overrun_error != overrun_error.first());

                      parity_error = parity_error.next();
                    end while (parity_error != parity_error.first());

                    frame_error = frame_error.next();
                  end while (frame_error != frame_error.first());

                  false_timing = false_timing.next();
                end while (false_timing != false_timing.first());

                start_type = start_type.next();
              end while (start_type != start_type.first());

              stop = stop.next();
            end while (stop != stop.first());

            parity_type = parity_type.next();
          end while (parity_type != parity_type.first());

          parity_en = parity_en.next();
        end while (parity_en != parity_en.first());

        data_width = data_width.next();
      end while (data_width != data_width.first());
    end

    $finish;
  end

  final begin
    $display("Simulation time is %0t", $time);
    if(error) begin
      $display("    ______                    ");
      $display("   / ____/_____________  _____");
      $display("  / __/ / ___/ ___/ __ \\/ ___/");
      $display(" / /___/ /  / /  / /_/ / /    ");
      $display("/_____/_/  /_/   \\____/_/     ");
      $display("Simulation Failed");
    end else begin
      $display("    ____  ___   __________");
      $display("   / __ \\/   | / ___/ ___/");
      $display("  / /_/ / /| | \\__ \\\__ \ ");
      $display(" / ____/ ___ |___/ /__/ / ");
      $display("/_/   /_/  |_/____/____/  ");
      $display();
      $display("Simulation Succeeded!");
    end
  end

endmodule
