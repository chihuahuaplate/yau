`timescale 1ns/1ps

module tb_uart();

  // bench variables
  bit error;

  // bench parameters
  parameter int clock_period_p = 10;
  parameter int clock_unit_p   = -9;
  parameter int reset_count_p  = 10;

  // bench time format
  initial begin
    $timeformat(clock_unit_p, 2, "ns");
  end
  // bench clock & reset
  bit           clk_i;
  bit           reset_i, _reset_i, reset_li;
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

  // Register address definitions
  typedef enum logic [2:0] {
    CTRL_ADDR     = 3'd0,
    STATUS_ADDR   = 3'd1,
    BAUD_DIV_ADDR = 3'd2,
    MODE_ADDR     = 3'd3,
    THR_ADDR      = 3'd4,
    RHR_ADDR      = 3'd5
  } uart_addr_e;

  // DUT parameters

  // DUT inputs
  // write address & data channel
  uart_addr_e  wr_addr_i;
  logic [31:0] wr_data_i;
  logic [3:0]  wr_strb_i;
  logic        wr_valid_i;
  // write response channel
  logic        wr_ready_i;
  // read adddress channel
  uart_addr_e  rd_addr_i;
  logic        rd_valid_i;
  // read response channel
  logic        rd_ready_i;
  // uart pin
  logic        rx_i;

  // DUT outputs

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
  // uart pin
  logic        tx_o;

  // DUT instance
  uart DUT (
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
    // uart
    .rx_i(rx_i),
    .tx_o(tx_o)
  );

  assign rx_i = tx_o;

  // Write data success
  bit wr_data_success;
  int wr_data_timeout;

  always_ff @(posedge clk_i) begin
    wr_data_success <= ((wr_ready_o === 1'b1) && wr_valid_i);
  end

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
  int wr_resp_timeout;

  always_ff @(posedge clk_i) begin
    wr_resp_success <= ((wr_valid_o === 1'b1) && wr_ready_i);
  end

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
  int rd_data_timeout;

  always_ff @(posedge clk_i) begin
    rd_data_success <= ((rd_ready_o === 1'b1) && rd_valid_i);
  end

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
  int rd_resp_timeout;

  always_ff @(posedge clk_i) begin
    rd_resp_success <= ((rd_valid_o === 1'b1) && rd_ready_i);
  end

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
    repeat (1) @(negedge clk_i);
    reset_li = 0;
  endtask

  // bench functions
  function int frequency_f;
    frequency_f = (1/(clock_period_p * $pow(10, clock_unit_p)));
  endfunction

  function int baud_div_f(
    input int baud_rate
  );
    baud_div_f = frequency_f() / (16 * baud_rate);
  endfunction

  // bench tasks

  task automatic write(
    input uart_addr_e address,
    input logic [31:0] data
  );
    wr_addr_i = address;
    wr_data_i = data;
    wr_strb_i = '1;

    wr_valid_i = 1;
    wait (wr_data_success == 1'b1);
    // $write("[%0t] WRITE[%p]: %0d ", $time, address, data);
    @(negedge clk_i);
    wr_valid_i = 0;

    wr_ready_i = 1;
    wait (wr_resp_success == 1'b1);
    // $write("[%0t] rd_error_o: %0b", $time, rd_error_o);
    // $display();
    @(negedge clk_i);
    wr_ready_i = 0;
  endtask

  task automatic read(
    input uart_addr_e address
  );
    rd_addr_i = address;

    rd_valid_i = 1;
    wait (rd_data_success == 1'b1);
    // $write("[%0t] READ[%p]: ", $time, address);
    @(negedge clk_i);
    rd_valid_i = 0;

    rd_ready_i = 1;
    wait (rd_resp_success == 1'b1);
    // $write("[%0t] rd_data_o:%0d rd_error_o: %0b", $time, rd_data_o, rd_error_o);
    // $display();
    @(negedge clk_i);
    rd_ready_i = 0;
  endtask

  task automatic read_until_cond(
    int baud_rate,
    uart_addr_e addr,
    bit [31:0] cond
  );
    bit [26:0] tx_baud_div;
    int        clock_count;

    tx_baud_div = (baud_div_f(baud_rate) * 16);

    do begin
      read(addr);
      if ((rd_data_o & cond) != cond) begin
        repeat (tx_baud_div) @(negedge clk_i);
      end else begin
        $display("[%0t] read_until_cond: %p = %0d", $time, addr, cond);
        break;
      end
    end while (1);
  endtask


  initial begin
    // default values
    wr_addr_i       = CTRL_ADDR;
    wr_data_i       = '0;
    wr_strb_i       = '0;
    wr_valid_i      = '0;
    wr_ready_i      = '0;
    rd_addr_i       = CTRL_ADDR;
    rd_valid_i      = '0;
    rd_ready_i      = '0;

    @(negedge reset_i);
    repeat (10) @(negedge clk_i);

    $display("[%0t] Simulation start.", $time);

    write(CTRL_ADDR, 3);
    write(BAUD_DIV_ADDR, baud_div_f(115200));
    write(MODE_ADDR, 3);        // 8N1

    // write data
    write(THR_ADDR, 85);
    write(THR_ADDR, 24);
    write(THR_ADDR, 67);
    write(THR_ADDR, 01);

    read_until_cond(115200, STATUS_ADDR, 2);
    read(RHR_ADDR);
    assert(rd_data_o == 85);
    read_until_cond(115200, STATUS_ADDR, 2);
    read(RHR_ADDR);
    assert(rd_data_o == 24);
    read_until_cond(115200, STATUS_ADDR, 2);
    read(RHR_ADDR);
    assert(rd_data_o == 67);
    read_until_cond(115200, STATUS_ADDR, 2);
    read(RHR_ADDR);
    assert(rd_data_o == 01);

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
