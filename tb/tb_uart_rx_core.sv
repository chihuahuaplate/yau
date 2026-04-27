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
  bit [26:0] rx_baud_div;

  task automatic configure_task(
    // TODO: baud_rate type, int or logic vector
    // input logic [26:0] baud_rate,
    input int baud_rate,
    input data_width_e data_width,
    input parity_en_e parity_en,
    input parity_type_e parity_type,
    input stop_e stop
  );

    $display("@%0t: Changing configuration.", $time);
    rx_baud_div = (1/(CLOCK_PERIOD_LP * $pow(10, CLOCK_UNIT_LP))) / (16 * baud_rate);
    config_i = {rx_baud_div, stop, parity_type, parity_en, data_width};
    $display("Baud rate: %0d, Baud div: %0d, Data width: %0p, Parity: %0p, Parity Type: %0p, Stop: %0p.",
             baud_rate, rx_baud_div, data_width, parity_en, parity_type, stop);
    @(negedge clk_i);
  endtask

  bit [26:0] tx_baud_div;
  bit tx_frame_q[$];
  int tx_data_len;
  bit tx_start;

  task automatic transmit_task(
    input int baud_rate,
    input data_width_e data_width,
    input parity_en_e parity_en,
    input parity_type_e parity_type,
    input stop_e stop,
    input logic [7:0] data,
    input logic frame_error,
    input logic parity_error,
    input logic false_start
  );

    // Baud divisor for Transmission
    tx_baud_div = (1/(CLOCK_PERIOD_LP * $pow(10, CLOCK_UNIT_LP))) / (baud_rate);

    // Construct tx_frame_q anew
    tx_frame_q.delete();

    // start bit
    tx_frame_q.push_back(1'b0);

    // data bits
    case (data_width)
      DW_5: tx_data_len = 5;
      DW_6: tx_data_len = 6;
      DW_7: tx_data_len = 7;
      DW_8: tx_data_len = 8;
    endcase

    for (int i = 0; i < tx_data_len; i++) begin
      if (parity_en && parity_error) begin
        // Flip an odd number of bits (1 in this case)
        if (i == 0) tx_frame_q.push_back(!data[i]);
        else tx_frame_q.push_back(data[i]);
      end else begin
        tx_frame_q.push_back(data[i]);
      end
    end

    // parity bit
    if (parity_en) begin
      tx_frame_q.push_back(parity_func(parity_type, data_width, data));
    end

    // stop bit
    if (stop) begin
      if (frame_error) begin
        tx_frame_q.push_back(1'b0);
        tx_frame_q.push_back(1'b1);
      end else begin
        tx_frame_q.push_back(1'b1);
        tx_frame_q.push_back(1'b1);
      end
    end else begin
      if (frame_error) begin
        tx_frame_q.push_back(1'b0);
      end else begin
        tx_frame_q.push_back(1'b1);
      end
    end

    $display("@%0t: Transmit frame constructed: %0p", $time, tx_frame_q);
    $display("@%0t: Transmit frame len: %0d", $time, tx_frame_q.size());

    tx_start = 1'b1;
    @(negedge clk_i);
    tx_start = 1'b0;

  endtask

  // Input generator (tx_i = rx_i)

  bit tx_i;
  bit tx_active;
  bit [26:0] tx_baud_count;
  bit [3:0] tx_frame_index;

  bit [7:0] tx_data;
  bit tx_frame_error;
  bit tx_parity_error;
  bit tx_false_start;
  bit [2:0] tx_false_start_pos;

  assign rx_i = tx_i;

  always @(posedge clk_i) begin
    if (reset_i) begin
      tx_i <= 1'b1;
      tx_active <= 1'b0;
      tx_baud_count <= '0;
      tx_frame_index <= '0;
    end else if (tx_active) begin
      tx_i <= tx_frame_q[tx_frame_index];

      tx_baud_count <= tx_baud_count + 1;
      if (tx_baud_count == (tx_baud_div - 1)) begin
        tx_baud_count <= '0;
        tx_frame_index <= tx_frame_index + 1;

        if (tx_frame_index == (tx_frame_q.size() - 1)) begin
          tx_active <= 1'b0;
        end
      end

      if (tx_false_start && tx_frame_index == 0) begin
        // Begin start bit
        if (tx_baud_count == '0) begin
          tx_i <= 1'b0;
        end else begin
          tx_i <= 1'b1;

          if (tx_baud_count >= ((rx_baud_div * (tx_false_start_pos + 1)) + 1)) begin
            tx_i <= 1'b0;
          end
        end
      end

    end else begin
      tx_i <= 1'b1;

      if (tx_start) begin
        tx_active <= 1'b1;
        tx_baud_count <= '0;
        tx_frame_index <= '0;
      end
    end
  end


  // test bench variables
  bit error;

  data_width_e  config_data_width;
  parity_en_e   config_parity_en;
  parity_type_e config_parity_type;
  stop_e        config_stop;
  bit [26:0] config_baud_rate [0:2];
  int config_baud_index;

  // Timer
  bit valid_test;
  int valid_count;

  always @(posedge clk_i) begin
    if (reset_i) begin
      valid_test <= 1'b0;
      valid_count <= 0;
    end if (valid_test) begin
      valid_count <= valid_count + 1;

      if (model_valid_o) begin
        valid_test <= 1'b0;
      end else begin

        if (valid_count > ((2 * tx_baud_div * tx_frame_q.size()) - 1)) begin
          valid_test <= 1'b0;
        end
      end
    end else begin
      if (tx_start) begin
        valid_test <= 1'b1;
        valid_count <= 0;
      end
    end
  end

  // Input Generator (config_i & data_i)
  initial begin
    // default assignments
    config_i = '0;

    config_baud_index = 0;
    config_baud_rate = '{38400, 57600, 115200};
    config_data_width = DW_8;
    config_parity_en = DISABLED;
    config_parity_type = ODD;
    config_stop = ONE_STOP;

    tx_data = 8'b0101_0101;
    tx_frame_error = 1'b0;
    tx_parity_error = 1'b0;
    tx_false_start = 0;
    tx_false_start_pos = 3'd0;

    @(negedge reset_i);
    repeat (2) @(negedge clk_i);

    $display("Simulation time is %0t", $time);
    $display("Input Generator, Start.");


    // Loop through baud rates
    for (config_baud_index = 0; config_baud_index < $size(config_baud_rate); config_baud_index++) begin

      // Loop through all data widths

      config_data_width = config_data_width.first();

      do begin

        // Loop through all parity enables
        config_parity_en = config_parity_en.first();
        do begin

          // Loop through all parity types
          config_parity_type = config_parity_type.first();
          do begin

            // Loop through all stop configs
            config_stop = config_stop.first();
            do begin

              tx_frame_error = 1'b0;
              do begin

                tx_parity_error = 1'b0;
                do begin

                  tx_false_start = 1'b0;
                  do begin

                    tx_false_start_pos = 3'b000;
                    do begin

                      tx_data = $urandom();
                      configure_task(
                        config_baud_rate[config_baud_index],
                        config_data_width,
                        config_parity_en,
                        config_parity_type,
                        config_stop
                      );

                      transmit_task(
                        config_baud_rate[config_baud_index],
                        config_data_width,
                        config_parity_en,
                        config_parity_type,
                        config_stop,
                        tx_data,
                        tx_frame_error,
                        tx_parity_error,
                        tx_false_start
                      );

                      wait (!valid_test);
                      wait (!tx_active);
                      repeat (10) @(negedge clk_i);

                      tx_false_start_pos += 1;
                    end while(tx_false_start_pos != 3'b000);

                    tx_false_start = !tx_false_start;
                  end while(tx_false_start != 1'b0);

                  tx_parity_error = !tx_parity_error;
                end while(tx_parity_error != 1'b0);

                tx_frame_error = !tx_frame_error;
              end while(tx_frame_error != 1'b0);

              config_stop = config_stop.next();
            end while (config_stop != config_stop.first());

            config_parity_type = config_parity_type.next();
          end while (config_parity_type != config_parity_type.first());

          // Next parity value
          config_parity_en = config_parity_en.next();
        end while (config_parity_en != config_parity_en.first());

        // Next data_width value
        config_data_width = config_data_width.next();
      end while (config_data_width != config_data_width.first());

    end // for (config_baud_index = 0; config_baud_index < $size(config_baud_rate); config_baud_index++)

    $finish();
  end


  // Behavioural model
  bit model_frame_q[$];
  int model_frame_size;
  bit [7:0] model_frame_data;

  bit       model_valid_o;
  bit [7:0] model_data_o;
  bit       model_frame_error_o;
  bit       model_parity_error_o;

  bit [26:0] model_clock_count;
  bit [26:0] model_clock_max;

  bit        model_active;
  bit        model_false_start;
  bit        model_negedge_rx;

  // Used for counting
  int        model_counter;

  detect_negedge model_negedge_detector(
    .clk_i(clk_i),
    .reset_i(reset_i),
    .sig_i(rx_i),
    .negedge_o(model_negedge_rx)
  );

  always @(posedge clk_i) begin
    if (reset_i) begin
      // outputs
      model_valid_o <= 1'b0;
      model_data_o <= '0;
      model_frame_error_o <= 1'b0;
      model_parity_error_o <= 1'b0;

      model_clock_count <= '0;
      model_clock_max <= '1;
      model_active <= 1'b0;
      model_false_start <= 1'b0;

      model_counter <= 0;
    end else if ($isunknown(valid_o)) begin
      $error("DUT produced unresolvable value on valid_o.");
      error = 1; #1;
      $finish();
    end else if ($isunknown(data_o)) begin
      $error("DUT produced unresolvable value on data_o.");
      error = 1; #1;
      $finish();
    end else if ($isunknown(frame_error_o)) begin
      $error("DUT produced unresolvable value on frame_error_o.");
      error = 1; #1;
      $finish();
    end else if ($isunknown(parity_error_o)) begin
      $error("DUT produced unresolvable value on parity_error_o.");
      error = 1; #1;
      $finish();
    end else begin

      if (!model_active) begin
        // outputs
        model_valid_o <= 1'b0;
        model_data_o <= '0;
        model_frame_error_o <= 1'b0;
        model_parity_error_o <= 1'b0;

        if (!model_false_start && model_negedge_rx) begin
          model_active <= 1'b1;
          model_clock_count <= '0;
          model_clock_max = ((rx_baud_div * 8) - 1) + ((rx_baud_div * 16) * (tx_frame_q.size() - 1));

          model_frame_q.delete();
          model_frame_data = 0;

          model_counter <= 0;
        end else begin
          model_false_start <= 1'b0;
        end

      end else begin
        model_clock_count <= model_clock_count + 1;
        model_counter <= model_counter + 1;

        // Stop bit
        if (model_clock_count <= (rx_baud_div * 8)) begin

          // At sample point
          if (model_counter == (rx_baud_div - 1)) begin
            model_counter <= '0;

            if (rx_i !== 1'b0) begin
              model_false_start <= 1'b1;
              model_active <= 1'b0;
            end
          end

          // push stop bit
          if (model_clock_count == (rx_baud_div * 8)) begin
            model_frame_q.push_back(1'b0);
          end
        end else if (model_clock_count >= (rx_baud_div * 16)) begin

          // Fist sample bit
          if (model_counter == ((rx_baud_div * 16) - 1)) begin
            model_counter <= '0;
            model_frame_q.push_back(rx_i);
          end
        end


        if (model_clock_count == model_clock_max) begin
          $display("@%0t: Model frame constructed: %0p", $time, model_frame_q);

          model_frame_size = model_frame_q.size();

          for (int i = 0; i < tx_data_len; i++) begin
            model_frame_data[i] = model_frame_q[i+1];
          end

          model_data_o <= model_frame_data;

          if (config_stop) begin
            // Two stops
            model_frame_error_o <= ~(model_frame_q[model_frame_size-1] & model_frame_q[model_frame_size-2]);
          end else begin
            // One stop
            model_frame_error_o <= ~(model_frame_q[model_frame_size-1]);
          end

          if (config_parity_en) begin
            model_parity_error_o <= parity_func(config_parity_type, config_data_width, model_frame_data) !=
                                    model_frame_q[tx_data_len+1];
          end

          model_valid_o <= 1'b1;
          model_active <= 1'b0;
        end
      end

      // Ensure valid_o always matches model_valid_o
      if (valid_o !== model_valid_o) begin
        $error("DUT output does not match model output.");
        $error("valid_o: (%b). model_valid_o (%b).",
               valid_o, model_valid_o);
        error = 1; #1;
        $finish();
      end

      if (model_valid_o) begin
        if (data_o !== model_data_o) begin
          $error("DUT output does not match model output.");
          $error("data_o: (%b). model_data_o (%b).",
                 data_o, model_data_o);
          error = 1; #1;
          $finish();
        end
        if (frame_error_o !== model_frame_error_o) begin
          $error("DUT output does not match model output.");
          $error("frame_error_o: (%b). model_frame_error_o (%b).",
                 frame_error_o, model_frame_error_o);
          error = 1; #1;
          $finish();
        end
        if (config_parity_en && (parity_error_o !== model_parity_error_o)) begin
          $error("DUT output does not match model output.");
          $error("parity_error_o: (%b). model_parity_error_o (%b).",
                 parity_error_o, model_parity_error_o);
          error = 1; #1;
          $finish();
        end

      end
    end
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
