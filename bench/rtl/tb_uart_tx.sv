`timescale 1ns / 1ps

module tb_uart_tx();

  // test bench vars
  bit error;

  typedef enum logic [1:0] {
    DW5 = 2'b00,
    DW6,
    DW7,
    DW8
  } data_width_e;

  typedef enum logic [1:0] {
    NONE = 2'b00,
    ODD  = 2'b01,
    EVEN = 2'b11
  } parity_e;

  typedef enum logic {
    ONE_STOP,
    TWO_STOP
  } stops_e;

  // parameters
  localparam CLOCK_PERIOD_P    = 10;
  localparam CLOCK_UNIT_P      = -9; // NOTE: -9 for nano second
  localparam RESET_COUNT_P     = 2;


  // clock & resets
  bit clk_i;
  bit _reset_i;
  bit reset_li;
  bit reset_i;
  assign reset_i = _reset_i | reset_li;

  // inputs
  logic [31:0] config_i;
  logic [7:0]  data_i;
  logic        valid_i;

  // outputs

  /* verilator lint_off UNOPTFLAT */
  logic ready_o;
  /* verilator lint_on UNOPTFLAT */
  logic tx_o;

  // clock & reset generator modules
  nonsynth_clock_gen #(
    .CLOCK_PERIOD_P(CLOCK_PERIOD_P)
  ) clk_gen (
    .clk_o(clk_i)
  );

  nonsynth_reset_gen #(
    .CLOCK_PERIOD_P(CLOCK_PERIOD_P),
    .RESET_COUNT_P(RESET_COUNT_P)
  ) reset_gen (
    .clk_i(clk_i),
    .async_reset_o(_reset_i)
  );

  // Device Under Test module
  uart_tx DUT (
    .clk_i(clk_i),
    .reset_i(reset_i),
    .config_i(config_i),
    .data_i(data_i),
    .valid_i(valid_i),
    .ready_o(ready_o),
    .tx_o(tx_o)
  );

  // Functions
  function bit [0:0] parity_func(
    input logic [0:0] parity_type,
    input data_width_e data_width,
    input logic [7:0] data
  );

    bit parity_bit;

    case (data_width)
      DW5: parity_bit = parity_type ? (^data[4:0]) : (~^data[4:0]);
      DW6: parity_bit = parity_type ? (^data[5:0]) : (~^data[5:0]);
      DW7: parity_bit = parity_type ? (^data[6:0]) : (~^data[6:0]);
      DW8: parity_bit = parity_type ? (^data[7:0]) : (~^data[7:0]);
    endcase

    parity_func = parity_bit;

  endfunction

  // Tasks
  task automatic uart_configure(
    input logic [26:0] baud_rate,
    input data_width_e data_width,
    input parity_e     parity,
    input stops_e      stops
  );

    bit [26:0] baud_divisor;

    $display("@%0t: Changing configuration.", $time);
    $display("Baud rate: %0d, Data width: %0p, Parity: %0p, Stops: %0p.",
             baud_rate, data_width, parity, stops);
    baud_divisor = (1/(CLOCK_PERIOD_P * $pow(10, CLOCK_UNIT_P))) / (baud_rate);

    config_i = {baud_divisor, stops, parity, data_width};
    @(negedge clk_i);

  endtask

  task automatic uart_transmit(
    input logic [7:0] data
  );

    $display("@%0t: Requesting transmit.", $time);
    valid_i = 1;
    data_i = data;
    @(negedge clk_i);
    valid_i = 0;

  endtask


  // Input generator
  // NOTE: Create test cases

  logic [26:0] baud_vec [0:6];
  data_width_e data_width_vec;
  parity_e parity_vec;
  stops_e stops_vec;

  initial begin
    config_i = '0;
    data_i   = $urandom();
    valid_i  = 0;
    baud_vec = '{0, 4800, 9600, 19200, 38400, 57600, 115200};

    @(negedge reset_i);
    repeat (2) @(negedge clk_i);

    $display("Simulation time is %0t", $time);
    $display("Input Generator, Start.");

    // Loop through baud rates to test against
    foreach (baud_vec[i]) begin

      // Loop through all data widths
      data_width_vec = data_width_vec.first();
      do begin

        // Loop through all parity options
        parity_vec = parity_vec.first();
        do begin

          // Loop through all stop options
          stops_vec = stops_vec.first();
          do begin

            // NOTE: Configure & Transmit
            uart_configure(baud_vec[i], data_width_vec, parity_vec, stops_vec);
            uart_transmit($urandom());

            if (baud_vec[i] == 0) begin
              // Baud rate of 0, change configuration after 10 cycles
              repeat (10) @(negedge clk_i);

            end else begin
              // valid transmission

              @(posedge ready_tl);
              @(negedge clk_i);

            end

            // Next stop value
            stops_vec = stops_vec.next();
          end while (stops_vec != stops_vec.first());

          // Next parity value
          parity_vec = parity_vec.next();
        end while (parity_vec != parity_vec.first());

        // Next data_width value
        data_width_vec = data_width_vec.next();
      end while (data_width_vec != data_width_vec.first());
    end


    $finish();
  end

  // Behavioral model of UART Transmitter

  bit ready_tl;                 // expected ready_o
  int tx_frame_len;             // Amound of symbols in a frame, depends on config_i

  // TODO: Explain the size
  bit [31:0] tx_clocks_max;
  bit [31:0] tx_clocks_count;

  bit [26:0] tx_baud_divisor;

  // Modeling ready_o
  always @(posedge clk_i) begin
    if (reset_i) begin
      ready_tl <= 1'b1;
      tx_frame_len = 0;
      tx_clocks_max = '1;
      tx_clocks_count <= 0;
    end else if ($isunknown(ready_o)) begin
      $error("DUT produced unresolvable value on ready_o.");
      error = 1'b1;
      $finish();
    end else begin

      // Model ready_tl behaviour
      if ((config_i[31:5] != 0) && valid_i && ready_o) begin
        ready_tl <= 1'b0;
        tx_frame_len = 0;
        tx_clocks_count <= '0;

        tx_baud_divisor = config_i[31:5];

        // Calculate frame length

        // start symbol
        tx_frame_len += 1;

        // data symbols
        case (config_i[1:0])
          DW5: tx_frame_len += 5;
          DW6: tx_frame_len += 6;
          DW7: tx_frame_len += 7;
          DW8: tx_frame_len += 8;
        endcase

        // parity
        case (config_i[3:2])
          NONE: tx_frame_len    += 0;
          EVEN: tx_frame_len    += 1;
          ODD: tx_frame_len     += 1;
          default: tx_frame_len += 0;
        endcase

        // stop bits
        case (config_i[4])
          ONE_STOP: tx_frame_len += 1;
          TWO_STOP: tx_frame_len += 2;
        endcase

        // Calculate number of clocks until transmission finishes
        tx_clocks_max = (tx_baud_divisor * tx_frame_len) - 1;

      end else begin // if ((config_i[31:5] != 0) && valid_i && ready_o)

        // Update clock count (actively transmitting)
        if (!ready_tl) begin
          tx_clocks_count <= tx_clocks_count + 1;
        end

        // Update expected ready_o (ready_tl) (finished transmission)
        if (tx_clocks_count == tx_clocks_max) begin
          ready_tl <= 1'b1;
        end
      end // else: !if((config_i[31:5] != 0) && valid_i && ready_o)

      // Check DUT output matches Model output.
      if (ready_o !== ready_tl) begin
        $error("DUT output does not match model output.");
        $error("DUT ready_o: (%b). Model output (%b).",
               ready_o, ready_tl);
        error = 1'b1;
        $finish();
      end

    end
  end

  // Modeling tx_o
  bit tx_tl;
  int tx_frame_index;
  int tx_data_width_lim;

  // Holds all bits expected to be sent out.
  // bits are sent out in descending order.
  // e.g START bit at back of queue, element before tail is lsb of data, etc.
  bit tx_frame_q [$];

  always @(posedge clk_i) begin
    if (reset_i) begin
      tx_tl <= 1'b1;
      tx_frame_index = 0;
      tx_frame_q.delete();
    end else if ($isunknown(tx_o)) begin
      $error("DUT produced unresolvable value on tx_o.");
      error = 1'b1;
      $finish();
    end else begin

      // Create the transmission frame
      if (ready_tl) begin
        tx_tl <= 1'b1;

        if (config_i[31:5] && valid_i) begin

          tx_frame_q.delete();

          // Start bit
          tx_frame_q.push_back(1'b0);

          // Data bits
          case (config_i[1:0])
            DW5: tx_data_width_lim = 5;
            DW6: tx_data_width_lim = 6;
            DW7: tx_data_width_lim = 7;
            DW8: tx_data_width_lim = 8;
          endcase

          for (int i = 0; i < tx_data_width_lim; i++) begin
            tx_frame_q.push_back(data_i[i]);
          end

          // parity bits
          if (config_i[2]) begin // parity_enable
            tx_frame_q.push_back(parity_func(config_i[3], data_width_e'(config_i[1:0]), data_i));
          end

          if (config_i[4]) begin
            // Two stop bits
            tx_frame_q.push_back(1'b1);
            tx_frame_q.push_back(1'b1);
          end else begin
            // One stop bit
            tx_frame_q.push_back(1'b1);
          end

          $display("Transmit frame constructed: %0p.", tx_frame_q);
        end // if (config_i[31:5] && valid_i)
      end else begin // if (ready_tl)

        tx_frame_index = tx_clocks_count / tx_baud_divisor;
        tx_tl <= tx_frame_q[tx_frame_index];

      end // else: !if(ready_tl)

      // Check DUT output matches Model output.
      if (tx_o !== tx_tl) begin
        $error("DUT output does not match model output.");
        $error("DUT tx_o: (%b). Model output (%b).",
               tx_o, tx_tl);
        error = 1'b1;
        $finish();
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
