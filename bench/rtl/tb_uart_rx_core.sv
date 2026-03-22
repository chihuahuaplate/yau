`timescale 1ns / 1ps

module tb_uart_rx_core();
  import uart_core_pkg::*;

  // parameters
  localparam CLOCK_PERIOD_LP = 10;
  localparam CLOCK_UNIT_LP = -9; // NOTE: -9 for nano second
  localparam RESET_COUNT_LP = 10;

  // clock & resets
  bit clk_i;
  bit _reset_i;
  bit reset_li;
  bit reset_i;
  assign reset_i = _reset_i | reset_li;

  // clock & reset generator modules
  nonsynth_clock_gen #(
    .CLOCK_PERIOD_P(CLOCK_PERIOD_LP)
  ) clk_gen (
    .clk_o(clk_i)
  );

  nonsynth_reset_gen #(
    .CLOCK_PERIOD_P(CLOCK_PERIOD_LP),
    .RESET_COUNT_P(RESET_COUNT_LP)
  ) reset_gen (
    .clk_i(clk_i),
    .async_reset_o(_reset_i)
  );

  // inputs
  logic [31:0] config_i;
  logic        rx_i;

  // outputs
  logic [7:0]  data_o;
  logic        valid_o;
  logic        frame_error_o;
  logic        parity_error_o;

  // Device Under Test
  uart_rx_core DUT (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .config_i(config_i),
    .rx_i(rx_i),
    .data_o(data_o),
    .valid_o(valid_o),
    .frame_error_o(frame_error_o),
    .parity_error_o(parity_error_o)
  );

  // functions
  function bit [0:0] parity_func(
    input parity_type_e parity_type,
    input data_width_e data_width,
    input logic [7:0] data
  );
    case (data_width)
      DW_5: parity_func = (parity_type == EVEN) ? (^data[4:0]) : !(^data[4:0]);
      DW_6: parity_func = (parity_type == EVEN) ? (^data[5:0]) : !(^data[5:0]);
      DW_7: parity_func = (parity_type == EVEN) ? (^data[6:0]) : !(^data[6:0]);
      DW_8: parity_func = (parity_type == EVEN) ? (^data[7:0]) : !(^data[7:0]);
    endcase
  endfunction

  // tasks
  task automatic reset_task(
    input int reset_count
  );
    $display("@%0t: Resetting for duration of %d cycles", $time, reset_count);
    _reset_i = 1'b1;
    repeat (reset_count) @(negedge clk_i);
    _reset_i = 1'b0;
    $display("@%0t: Resetting finished", $time);
  endtask

  // Configures the receiver
  task automatic configure_task(
    // TODO: baud_rate type, int or logic vector
    // input logic [26:0] baud_rate,
    input int baud_rate,
    input data_width_e data_width,
    input parity_en_e parity_en,
    input parity_type_e parity_type,
    input stop_e stop
  );
    bit [26:0] baud_div;

    $display("@%0t: Changing configuration.", $time);
    baud_div = (1/(CLOCK_PERIOD_LP * $pow(10, CLOCK_UNIT_LP))) / (16 * baud_rate);
    config_i = {baud_div, stop, parity_type, parity_en, data_width};
    $display("Baud rate: %0d, Baud div: %0d, Data width: %0p, Parity: %0p, Parity Type: %0p, Stop: %0p.",
             baud_rate, baud_div, data_width, parity_en, parity_type, stop);
    @(negedge clk_i);
  endtask

  task automatic transmit_task(
    input int        baud_rate,
    input            data_width_e data_width,
    input            parity_en_e parity_en,
    input            parity_type_e parity_type,
    input            stop_e stop,
    input logic [7:0] data,
      // TOOD: Add errors
    input logic frame_error,
    input logic parity_error
  );
    // Baud divisor for Transmission
    bit [26:0] baud_div;
    int tx_data_len;

    baud_div = (1/(CLOCK_PERIOD_LP * $pow(10, CLOCK_UNIT_LP))) / (baud_rate);

    tb_frame_q.delete();
    // Construct tb_frame_q
    // start bit
    tb_frame_q.push_back(1'b0);

    // data bits
    case (data_width)
      DW_5: tx_data_len = 5;
      DW_6: tx_data_len = 6;
      DW_7: tx_data_len = 7;
      DW_8: tx_data_len = 8;
    endcase

    for (int i = 0; i < tx_data_len; i++) begin
      if (parity_en && parity_error) begin
        if (i == 0) begin
          tb_frame_q.push_back(!data[i]);
        end else begin
          tb_frame_q.push_back(data[i]);
        end
      end else begin
        tb_frame_q.push_back(data[i]);
      end
    end

    // parity bit
    if (parity_en) begin
      tb_frame_q.push_back(parity_func(parity_type, data_width, data));
    end

    // stop bit
    if (stop) begin
      if (frame_error) begin
        tb_frame_q.push_back(1'b0);
        tb_frame_q.push_back(1'b1);
      end else begin
        tb_frame_q.push_back(1'b1);
        tb_frame_q.push_back(1'b1);
      end
    end else begin
      if (frame_error) begin
        tb_frame_q.push_back(1'b0);
      end else begin
        tb_frame_q.push_back(1'b1);
      end
    end

    $display("@%0t: Transmit frame constructed: %0p", $time, tb_frame_q);
    $display("@%0t: Transmit frame len: %0d", $time, tb_frame_q.size());

    foreach(tb_frame_q[i]) begin
      rx_i = tb_frame_q[i];
      repeat (baud_div) @(negedge clk_i);
    end

  endtask

  // test bench variables
  bit tb_error;

  bit tb_frame_q [$];

  int tb_baud_index;
  logic [26:0] tb_baud_rate [0:5];
  data_width_e  tb_data_width;
  parity_en_e   tb_parity_en;
  parity_type_e tb_parity_type;
  stop_e        tb_stop;
  logic [7:0] tb_tx_data;
  bit tb_frame_error;
  bit tb_parity_error;

  // Input Generator
  initial begin
    // default assignments
    config_i = '0;
    rx_i = 1;

    tb_baud_rate = '{4800, 9600, 19200, 38400, 57600, 115200};
    tb_data_width = DW_8;
    tb_parity_en = DISABLED;
    tb_parity_type = ODD;
    tb_stop = ONE_STOP;
    tb_tx_data = 8'b0101_0101;
    tb_frame_error = 1'b0;
    tb_parity_error = 1'b0;

    @(negedge reset_i);

    $display("Simulation time is %0t", $time);
    $display("Input Generator, Start.");

    // Loop through baud rates
    tb_baud_index = 0;
    for (tb_baud_index = 0; tb_baud_index < $size(tb_baud_rate); tb_baud_index++) begin
    // foreach (tb_baud_rate[i]) begin

      // Loop through all data widths
      tb_data_width = tb_data_width.first();
      do begin

        // Loop through all parity enables
        tb_parity_en = tb_parity_en.first();
        do begin

          // Loop through all parity types
          tb_parity_type = tb_parity_type.first();
          do begin

            // Loop through all stop configs
            tb_stop = tb_stop.first();
            do begin

              tb_frame_error = 1'b0;
              do begin

                tb_parity_error = 1'b0;
                do begin

                  tb_tx_data = $urandom();
                  configure_task(
                    tb_baud_rate[tb_baud_index],
                    tb_data_width,
                    tb_parity_en,
                    tb_parity_type,
                    tb_stop
                  );
                  transmit_task(
                    tb_baud_rate[tb_baud_index],
                    tb_data_width,
                    tb_parity_en,
                    tb_parity_type,
                    tb_stop,
                    tb_tx_data,
                    tb_frame_error,
                    tb_parity_error
                  );

                  rx_i = 1;     // Set to IDLE
                  repeat(100) @(negedge clk_i);

                  tb_parity_error = !tb_parity_error;
                end while(tb_parity_error != 1'b0);

                tb_frame_error = !tb_frame_error;
              end while(tb_frame_error != 1'b0);

              tb_stop = tb_stop.next();
            end while (tb_stop != tb_stop.first());

            tb_parity_type = tb_parity_type.next();
          end while (tb_parity_type != tb_parity_type.first());

          // Next parity value
          tb_parity_en = tb_parity_en.next();
        end while (tb_parity_en != tb_parity_en.first());

        // Next data_width value
        tb_data_width = tb_data_width.next();
      end while (tb_data_width != tb_data_width.first());

    end // for (tb_baud_index = 0; tb_baud_index < $size(tb_baud_rate); tb_baud_index++)

    repeat (10) @(negedge clk_i);

    $finish();
  end

  // Behavioural model
  bit model_valid_o;
  bit model_frame_error_o;
  bit model_parity_error_o;

  bit model_in_rx;
  int model_clk_count;
  int model_clk_max;
  int model_rx_max;

  bit model_negedge_rx;
  detect_negedge model_negedge_detector(
    .clk_i(clk_i),
    .reset_i(reset_i),
    .sig_i(rx_i),
    .negedge_o(model_negedge_rx)
  );

  always @(posedge clk_i) begin
    if (reset_i) begin
      model_valid_o <= 1'b0;
      model_frame_error_o <= 1'b0;
      model_parity_error_o <= 1'b0;
      model_in_rx <= 1'b0;
    end else if ($isunknown(valid_o)) begin
      $error("DUT produced unresolvable value on valid_o.");
      tb_error = 1; #1;
      $finish();
    end else if ($isunknown(frame_error_o)) begin
      $error("DUT produced unresolvable value on frame_error_o.");
      tb_error = 1; #1;
      $finish();
    end else if ($isunknown(parity_error_o)) begin
      $error("DUT produced unresolvable value on parity_error_o.");
      tb_error = 1; #1;
      $finish();
    end else begin

      if (!model_in_rx) begin
        model_valid_o <= 1'b0;
        model_frame_error_o <= 1'b0;
        model_parity_error_o <= 1'b0;

        if (model_negedge_rx) begin
          model_in_rx <= 1'b1;
          model_clk_count <= '0;

          // record errors
          model_frame_error_o <= tb_frame_error;
          model_parity_error_o <= tb_parity_error;

          // rx_baud_max
          model_rx_max = ((1/(CLOCK_PERIOD_LP * $pow(10, CLOCK_UNIT_LP))) / (16 * tb_baud_rate[tb_baud_index]));
          model_clk_max = (model_rx_max * 8) - 1; // clocks to center on stop bit
          model_clk_max = model_clk_max + (model_rx_max * 16) * (tb_frame_q.size() - 1);
        end
      end else begin
        model_clk_count <= model_clk_count + 1;

        if (model_clk_count == model_clk_max) begin
          model_valid_o <= 1'b1;
          model_in_rx <= 1'b0;
        end
      end

      // Ensure valid_o always matches model_valid_o
      if (valid_o !== model_valid_o) begin
        $error("DUT output does not match model output.");
        $error("valid_o: (%b). model_valid_o (%b).",
               valid_o, model_valid_o);
        tb_error = 1; #1;
        $finish();
      end

      // When model_valid_o HIGH ensure errors are reported correctly
      if (model_valid_o) begin
        if (frame_error_o !== model_frame_error_o) begin
          $error("DUT output does not match model output.");
          $error("frame_error_o: (%b). model_frame_error_o (%b).",
                 frame_error_o, model_frame_error_o);
          tb_error = 1; #1;
          $finish();
        end
        if (tb_parity_en && (parity_error_o !== model_parity_error_o)) begin
          $error("DUT output does not match model output.");
          $error("parity_error_o: (%b). model_parity_error_o (%b).",
                 parity_error_o, model_parity_error_o);
          tb_error = 1; #1;
          $finish();
        end
      end
    end
  end


  final begin
    $display("Simulation time is %0t", $time);
    if(tb_error) begin
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
