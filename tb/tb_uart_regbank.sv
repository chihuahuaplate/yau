`timescale 1ns/1ps

module tb_uart_regbank();

  // global vars
  bit error;

  // Simulation settings
  initial begin
    $timeformat(-9, 2, "ns");
  end

  // Test bench parameters
  parameter int clock_period_p = 10;
  parameter int reset_count_p  = 10;

  // Test bench clock
  bit           clk_i;

  nonsynth_clock_gen #(
    .CLOCK_PERIOD_P(clock_period_p)
  ) clock_gen (
    .clk_o(clk_i)
  );

  // Test bench reset
  bit _reset_i;
  bit reset_li;   //
  bit reset_i;
  assign reset_i = _reset_i || reset_li;

  nonsynth_reset_gen #(
    .CLOCK_PERIOD_P(clock_period_p),
    .RESET_COUNT_P(reset_count_p)
  ) reset_gen (
    .clk_i(clk_i),
    .async_reset_o(_reset_i)
  );

  // NOTE: DUT parameters

  // NOTE: DUT inputs
  // write address & data channel
  logic [2:0]  wr_addr_i;
  logic [31:0] wr_data_i;
  logic [3:0]  wr_strb_i;
  logic        wr_valid_i;
  // write response channel
  logic        wr_ready_i;
  // read adddress channel
  logic [2:0]  rd_addr_i;
  logic        rd_valid_i;
  // read response channel
  logic        rd_ready_i;

  // STATUS signals
  logic rx_fifo_empty_i;
  logic tx_fifo_empty_i;
  logic rx_fifo_full_i;
  logic tx_fifo_full_i;
  logic overrun_error_i;
  logic parity_error_i;
  logic frame_error_i;
  logic data_ready_i;

  // THR signals
  logic        tx_fifo_ready_i;

  // RHR signals
  logic       rx_fifo_valid_i;
  logic [7:0] rx_fifo_data_i;

  // NOTE: DUT outputs
  // write adddress && data channel
  logic        wr_ready_o;
  // write response channel
  logic        wr_valid_o;
  logic        wr_error_o;

  // read address channel
  logic        rd_ready_o;
  // read response channel
  logic        rd_valid_o;
  logic [31:0] rd_data_o;
  logic        rd_error_o;

  // CTRL signals
  logic reset_rx_uart_o;
  logic reset_tx_uart_o;
  logic reset_rx_fifo_o;
  logic reset_tx_fifo_o;
  logic en_rx_uart_o;
  logic en_tx_uart_o;

  // BAUD_DIV & MODE signals
  logic [31:0] config_o;

  // THR signals
  logic       thr_valid_o;
  logic [7:0] thr_data_o;

  // RHR signals
  logic       rhr_ready_o;

  // DUT instance
  uart_regbank DUT (
    .clk_i(clk_i),
    .reset_i(reset_i),
    // Register interface
    .wr_addr_i(wr_addr_i),
    .wr_data_i(wr_data_i),
    .wr_strb_i(wr_strb_i),
    .wr_ready_o(wr_ready_o),
    .wr_valid_i(wr_valid_i),
    .wr_ready_i(wr_ready_i),
    .wr_valid_o(wr_valid_o),
    .wr_error_o(wr_error_o),
    .rd_addr_i(rd_addr_i),
    .rd_ready_o(rd_ready_o),
    .rd_valid_i(rd_valid_i),
    .rd_ready_i(rd_ready_i),
    .rd_valid_o(rd_valid_o),
    .rd_data_o(rd_data_o),
    .rd_error_o(rd_error_o),
    // Core interface
    .reset_rx_uart_o(reset_rx_uart_o),
    .reset_tx_uart_o(reset_tx_uart_o),
    .reset_rx_fifo_o(reset_rx_fifo_o),
    .reset_tx_fifo_o(reset_tx_fifo_o),
    .en_rx_uart_o(en_rx_uart_o),
    .en_tx_uart_o(en_tx_uart_o),
    .rx_fifo_empty_i(rx_fifo_empty_i),
    .tx_fifo_empty_i(rx_fifo_empty_i),
    .rx_fifo_full_i(rx_fifo_full_i),
    .tx_fifo_full_i(tx_fifo_full_i),
    .overrun_error_i(overrun_error_i),
    .parity_error_i(parity_error_i),
    .frame_error_i(frame_error_i),
    .data_ready_i(data_ready_i),
    .config_o(config_o),
    .tx_fifo_ready_i(tx_fifo_ready_i),
    .thr_valid_o(thr_valid_o),
    .thr_data_o(thr_data_o),
    .rhr_ready_o(rhr_ready_o),
    .rx_fifo_valid_i(rx_fifo_valid_i),
    .rx_fifo_data_i(rx_fifo_data_i)
  );

  // Write data success
  bit wr_data_success;
  always_ff @(posedge clk_i) begin
    wr_data_success <= ((wr_ready_o === 1'b1) && wr_valid_i);
  end

  int wr_data_timeout;
  always @(posedge clk_i) begin
    if (reset_i || ((wr_ready_o === 1'b1) && wr_valid_i)) begin
      wr_data_timeout <= 0;
    end else if (wr_data_timeout > 10) begin
      $error("[%0t] Timeout on Write addr/data channel. wr_valid_i was high for 10 cycles with no response.", $time);
      error = 1; #1;
      $finish();
    end else if (wr_valid_i && (wr_ready_o !== 1'b1)) begin
      wr_data_timeout <= wr_data_timeout + 1;
    end
  end

  // Write response success
  bit wr_resp_success;
  always_ff @(posedge clk_i) begin
    wr_resp_success <= ((wr_valid_o === 1'b1) && wr_ready_i);
  end

  int wr_resp_timeout;
  always @(posedge clk_i) begin
    if (reset_i || ((wr_valid_o === 1'b1) && wr_ready_i)) begin
      wr_resp_timeout <= 0;
    end else if (wr_resp_timeout > 10) begin
      $error("[%0t] Timeout on Write response channel. wr_ready_i was high for 10 cycles with no response.", $time);
      error = 1; #1;
      $finish();
    end else if (wr_ready_i && (wr_valid_o !== 1'b1)) begin
      wr_resp_timeout <= wr_resp_timeout + 1;
    end
  end

  // Read data success
  bit rd_data_success;
  always_ff @(posedge clk_i) begin
    rd_data_success <= ((rd_ready_o === 1'b1) && rd_valid_i);
  end

  int rd_data_timeout;
  always @(posedge clk_i) begin
    if (reset_i || ((rd_ready_o === 1'b1) && rd_valid_i)) begin
      rd_data_timeout <= 0;
    end else if (rd_data_timeout > 10) begin
      $error("[%0t] Timeout on Read address channel. rd_valid_i was high for 10 cycles with no response.", $time);
      error = 1; #1;
      $finish();
    end else if (rd_valid_i && (rd_ready_o !== 1'b1)) begin
      rd_data_timeout <= rd_data_timeout + 1;
    end
  end

  // Read response success
  bit rd_resp_success;
  always_ff @(posedge clk_i) begin
    rd_resp_success <= ((rd_valid_o === 1'b1) && rd_ready_i);
  end

  int rd_resp_timeout;
  always @(posedge clk_i) begin
    if (reset_i || ((rd_valid_o === 1'b1) && rd_ready_i)) begin
      rd_resp_timeout <= 0;
    end else if (rd_resp_timeout > 10) begin
      $error("[%0t] Timeout on Read response channel. rd_ready_i was high for 10 cycles with no response.", $time);
      error = 1; #1;
      $finish();
    end else if (rd_ready_i && (rd_valid_o !== 1'b1)) begin
      rd_resp_timeout <= rd_resp_timeout + 1;
    end
  end

  task automatic reset;
    reset_li = 1;
    repeat (reset_count_p) @(negedge clk_i);
    reset_li = 0;
  endtask

  // Register address definitions
  typedef enum logic [2:0] {
    CTRL_ADDR     = 3'd0,
    STATUS_ADDR   = 3'd1,
    BAUD_DIV_ADDR = 3'd2,
    MODE_ADDR     = 3'd3,
    THR_ADDR      = 3'd4,
    RHR_ADDR      = 3'd5
  } uart_addr_e;

  task automatic write(
    input uart_addr_e address,
    input logic [31:0] data
  );
    wr_addr_i = address;
    wr_data_i = data;
    wr_strb_i = '1;

    wr_valid_i = 1;
    wait (wr_data_success == 1'b1);
    $write("[%0t] WRITE[%p]: %0d ", $time, address, data);
    wr_valid_i = 0;
    @(negedge clk_i);

    wr_ready_i = 1;
    wait (wr_resp_success == 1'b1);
    if (wr_error_o) $write("[FAIL]");
    else $write("[PASS]");
    $display();
    wr_ready_i = 0;
    @(negedge clk_i);

  endtask

  task automatic read(
    input uart_addr_e address
  );
    rd_addr_i = address;

    rd_valid_i = 1;
    wait (rd_data_success == 1'b1);
    $write("[%0t] READ[%p]: ", $time, address);
    rd_valid_i = 0;
    @(negedge clk_i);

    rd_ready_i = 1;
    wait (rd_resp_success == 1'b1);
    $write("%0d ", rd_data_o);
    if (rd_error_o) $write("[FAIL]");
    else $write("[PASS]");
    $display();
    rd_ready_i = 0;
    @(negedge clk_i);

  endtask

  initial begin
    // default values
    wr_addr_i       = '0;
    wr_data_i       = '0;
    wr_strb_i       = '0;
    wr_valid_i      = '0;
    wr_ready_i      = '0;
    rd_addr_i       = '0;
    rd_valid_i      = '0;
    rd_ready_i      = '0;
    rx_fifo_empty_i = '0;
    tx_fifo_empty_i = '0;
    rx_fifo_full_i  = '0;
    tx_fifo_full_i  = '0;
    overrun_error_i = '0;
    parity_error_i  = '0;
    frame_error_i   = '0;
    data_ready_i    = '0;
    tx_fifo_ready_i = '0;
    rx_fifo_valid_i = '0;
    rx_fifo_data_i  = '0;

    @(negedge reset_i);
    repeat (10) @(negedge clk_i);

    $display("[%0t] Simulation start.", $time);

    $display();
    $display("[%0t] Write to all registers", $time);

    write(CTRL_ADDR, 3);        // Disable resets & enable uarts
    write(STATUS_ADDR, 0);
    write(BAUD_DIV_ADDR, 868);  // 115200 Baud
    write(MODE_ADDR, 3);        // 8N1
    write(THR_ADDR, 55);
    write(RHR_ADDR, 0);

    $display();
    $display("[%0t] Read from all registers", $time);
    read(CTRL_ADDR);
    read(STATUS_ADDR);
    read(BAUD_DIV_ADDR);
    read(MODE_ADDR);
    read(THR_ADDR);
    read(RHR_ADDR);

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
