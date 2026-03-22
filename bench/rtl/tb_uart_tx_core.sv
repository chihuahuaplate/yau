`timescale 1ns / 1ps

module tb_uart_tx_core();
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
  logic [7:0]  data_i;
  logic        valid_i;

  // outputs
  logic ready_o;
  logic tx_o;

  // Device Under Test
  uart_tx_core DUT (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .config_i(config_i),
    .data_i(data_i),
    .valid_i(valid_i),
    .ready_o(ready_o),
    .tx_o(tx_o)
  );

  // Test bench vars
  logic [26:0] tb_baud_rate [0:6];
  data_width_e  tb_data_width;
  parity_en_e   tb_parity_en;
  parity_type_e tb_parity_type;
  stop_e        tb_stop;

  bit tb_error;

  // Test bench functions
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

  // Test bench tasks
  task automatic transmit_task(
    input logic [7:0] data
  );
    // $display("@%0t: Requesting transmit.", $time);
    // valid_i = 1;
    // data_i  = data;
    // @(negedge clk_i);
    // valid_i = 0;

    $display("@%0t: Requesting transmit.", $time);
    data_i  = data;
    valid_i = 1'b1;

    do begin
      @(negedge clk_i);
    end while ((valid_i == 1'b1) && (wr_success == 1'b0));

    valid_i = 1'b0;
  endtask

  task automatic configure_task(
    input logic [26:0] baud_rate,
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

  task automatic reset_task(
    input int reset_count
  );

    $display("@%0t: Resetting for duration of %d cycles", $time, reset_count);
    _reset_i = 1'b1;
    repeat (reset_count) @(negedge clk_i);
    _reset_i = 1'b0;
    $display("@%0t: Resetting finished", $time);

  endtask

  // Input Generator
  bit wr_success;
  always_ff @(posedge clk_i) begin
    wr_success <= valid_i & (ready_o === 1'b1);
  end

  initial begin
    tb_baud_rate = '{0, 4800, 9600, 19200, 38400, 57600, 115200};

    tb_data_width = DW_8;
    tb_parity_en = DISABLED;
    tb_parity_type = ODD;
    tb_stop = ONE_STOP;

    config_i = '0;
    data_i = '0;
    valid_i = 1'b0;

    @(negedge reset_i);

    $display("Simulation time is %0t", $time);
    $display("Input Generator, Start.");


    // Loop through baud rates
    foreach (tb_baud_rate[i]) begin

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

              // NOTE: Configure & Transmit
                configure_task(tb_baud_rate[i], tb_data_width, tb_parity_en, tb_parity_type, tb_stop);
                transmit_task($urandom());

              if (tb_baud_rate[i] == 0) begin
                // baud_rate of 0 causes underflow of baud_max in transmitter
                repeat (10) @(negedge clk_i);
              end else begin
                @(posedge model_ready_o);
                @(negedge clk_i);
              end

              reset_task(RESET_COUNT_LP);

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

    end // foreach (tb_baud_rate[i])

    repeat (10) @(negedge clk_i);

    $finish();

  end

  // Behavioural model
  bit model_ready_o = 1'b0;
  bit model_tx_o = 1'b1;

  bit model_in_reset;
  bit model_in_tx;              // model is transmitting

  int model_frame_len;
  int model_data_len;
  int model_frame_index;

  bit [26:0] model_baud_max;
  bit [26:0] model_baud_count;

  bit model_frame_q [$];

  always @(posedge clk_i) begin
    if (reset_i) begin
      model_ready_o <= 1'b0;
      model_tx_o <= 1'b1;

      model_in_reset <= 1'b1;
      model_in_tx <= 1'b0;

      model_frame_len = 12;     // largest frame possible
      model_frame_index <= 0;

    end else if ($isunknown(ready_o)) begin
         $error("DUT produced unresolvable value on ready_o.");
         tb_error = 1; #1;
         $finish();
    end else if ($isunknown(tx_o)) begin
         $error("DUT produced unresolvable value on tx_o.");
         tb_error = 1; #1;
         $finish();
    end else begin

      // Set model_ready_o HIGH after a reset
      if (model_in_reset) begin
        model_in_reset <= 1'b0;
        model_ready_o <= 1'b1;
      end else begin

        // Not in a transmission -> able to commence a transmission
        if (!model_in_tx && model_ready_o && valid_i) begin
        // if (!model_in_tx && (config_i[31:5] != '0) && model_ready_o && valid_i) begin
          model_in_tx <= 1'b1;
          model_ready_o <= #CLOCK_PERIOD_LP 1'b0;

          // reset frame index
          model_frame_index <= 0;

          model_frame_q.delete();

          model_baud_max = (config_i[31:5] << 4) - 1;
          model_baud_count <= 0;

          // calculate frame length

          // start bit
          model_frame_len = 1;
          model_frame_q.push_back(1'b0);

          // data bits
          case (config_i[1:0])
            DW_5: model_data_len = 5;
            DW_6: model_data_len = 6;
            DW_7: model_data_len = 7;
            DW_8: model_data_len = 8;
          endcase

          model_frame_len += model_data_len;

          for (int i = 0; i < model_data_len; i++) begin
            model_frame_q.push_back(data_i[i]);
          end


          // parity bit
          if (config_i[2]) begin
            model_frame_len += 1;
            model_frame_q.push_back(
              parity_func(
                parity_type_e'(config_i[3]),
                data_width_e'(config_i[1:0]),
                data_i
              )
            );
          end

          // stop bit
          if (config_i[4]) begin
            model_frame_len += 2;
            model_frame_q.push_back(1'b1);
            model_frame_q.push_back(1'b1);
          end else begin
            model_frame_len += 1;
            model_frame_q.push_back(1'b1);
          end

          $display("Model frame constructed: %0p", model_frame_q);
          $display("Model frame length: %0d", model_frame_len);

        end else if (model_in_tx) begin


          if (model_frame_index == model_frame_len) begin
            // Reached end of transmission
            model_in_tx <= 1'b0;
            model_ready_o <= 1'b1;
            model_tx_o <= 1'b1;
          end else begin
            model_tx_o <= model_frame_q[model_frame_index];

            if (model_baud_count == model_baud_max) begin
              // One baud has occured
              model_baud_count <= 0;
              model_frame_index <= model_frame_index + 1;
            end else begin
              model_baud_count <= model_baud_count + 1;
            end

          end

        end // if (model_in_tx)
      end

      if (ready_o !== model_ready_o) begin
        $error("DUT output does not match model output.");
        $error("ready_o: (%b). model_ready_o (%b).",
               ready_o, model_ready_o);
        tb_error = 1; #1;
        $finish();
      end

      if (tx_o !== model_tx_o) begin
        $error("DUT output does not match model output.");
        $error("tx_o: (%b). model_tx_o (%b).",
               tx_o, model_tx_o);
        tb_error = 1; #1;
        $finish();
      end

    end // else: !if(reset_i)
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
