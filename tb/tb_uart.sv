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
    RHR_ADDR      = 3'd5,
    INVALID_ADDR_1,
    INVALID_ADDR_2
  } uart_addr_e;

  // DUT inputs & outputs
  wire          resetn_i;
  assign resetn_i = !reset_i;

  uart_addr_e s_axil_awaddr_i;
  logic [2:0] s_axil_awprot_i;
  logic       s_axil_awvalid_i;
  logic       s_axil_awready_o;
  // W Channel
  logic [31:0] s_axil_wdata_i;
  logic [3:0]  s_axil_wstrb_i;
  logic        s_axil_wvalid_i;
  logic        s_axil_wready_o;
  // B Channel
  logic [1:0] s_axil_bresp_o;
  logic       s_axil_bvalid_o;
  logic       s_axil_bready_i;
  // AR Channel
  uart_addr_e s_axil_araddr_i;
  logic [2:0] s_axil_arprot_i;
  logic       s_axil_arvalid_i;
  logic       s_axil_arready_o;
  // R Channel
  logic [31:0] s_axil_rdata_o;
  logic [1:0]  s_axil_rresp_o;
  logic        s_axil_rvalid_o;
  logic        s_axil_rready_i;
  // Uart pins
  logic        rx_i;
  logic        tx_o;

  // DUT instance
  uart DUT (
    .clk_i(clk_i),
    .resetn_i(resetn_i),
    // Register interface
    .s_axil_awaddr_i(s_axil_awaddr_i),
    .s_axil_awprot_i(s_axil_awprot_i),
    .s_axil_awvalid_i(s_axil_awvalid_i),
    .s_axil_awready_o(s_axil_awready_o),
    .s_axil_wdata_i(s_axil_wdata_i),
    .s_axil_wstrb_i(s_axil_wstrb_i),
    .s_axil_wvalid_i(s_axil_wvalid_i),
    .s_axil_wready_o(s_axil_wready_o),
    .s_axil_bresp_o(s_axil_bresp_o),
    .s_axil_bvalid_o(s_axil_bvalid_o),
    .s_axil_bready_i(s_axil_bready_i),
    .s_axil_araddr_i(s_axil_araddr_i),
    .s_axil_arprot_i(s_axil_arprot_i),
    .s_axil_arvalid_i(s_axil_arvalid_i),
    .s_axil_arready_o(s_axil_arready_o),
    .s_axil_rdata_o(s_axil_rdata_o),
    .s_axil_rresp_o(s_axil_rresp_o),
    .s_axil_rvalid_o(s_axil_rvalid_o),
    .s_axil_rready_i(s_axil_rready_i),
    // uart
    .rx_i(rx_i),
    .tx_o(tx_o)
  );

  assign rx_i = tx_o;

  task reset;
    reset_li = 1;
    repeat (reset_count_p) @(negedge clk_i);
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

  task write(
    input uart_addr_e  addr,
    input bit [31:0] data
  );
    s_axil_awaddr_i = addr;
    s_axil_wdata_i = data;
    s_axil_wstrb_i = 4'hF;

    fork
      begin
        #($urandom_range(0, 0));
        s_axil_awvalid_i = #(clock_period_p * $urandom_range(0, 5)) 1;
        wait (s_axil_awvalid_i && s_axil_awready_o);
        @(posedge clk_i);
        $write("[%0t] WRITE Addr: %0p ", $time, s_axil_awaddr_i);
      end
      begin
        s_axil_wvalid_i = #(clock_period_p * $urandom_range(0, 5)) 1;
        wait (s_axil_wvalid_i && s_axil_wready_o);
        @(posedge clk_i);
        $write("[%0t] WRITE Data: 32'b%0b ", $time, s_axil_wdata_i);
      end
    join

    @(negedge clk_i);

    s_axil_awvalid_i = 0;
    s_axil_wvalid_i = 0;

    #(clock_period_p * $urandom_range(0, 5)) s_axil_bready_i = 1;
    wait (s_axil_bready_i && s_axil_bvalid_o);
    @(posedge clk_i);
    if (s_axil_bresp_o == 2'b00) $display("[%0t] PASS", $time);
    else $display("[%0t] FAIL", $time);
    @(negedge clk_i);
    s_axil_bready_i = 0;
  endtask

  task read(
    input uart_addr_e addr
  );
    s_axil_araddr_i = addr;

    #(clock_period_p * $urandom_range(0, 5)) s_axil_arvalid_i = 1;
    wait (s_axil_arvalid_i && s_axil_arready_o);
    @(posedge clk_i);
    $write("[%0t] Read Addr: %0p ", $time, s_axil_araddr_i);
    @(negedge clk_i);

    s_axil_arvalid_i = 0;

    #(clock_period_p * $urandom_range(0, 5)) s_axil_rready_i = 1;
    wait (s_axil_rready_i && s_axil_rvalid_o);
    @(posedge clk_i);
    $write("[%0t] Read Data: 32'b%0b ", $time, s_axil_rdata_o);
    if (s_axil_rresp_o == 2'b00) $display("[%0t] PASS", $time);
    else $display("[%0t] FAIL", $time);
    @(negedge clk_i);
    s_axil_rready_i = 0;
  endtask

  // task automatic write(
  //   input uart_addr_e address,
  //   input logic [31:0] data
  // );
  //   s_axil_awaddr_i = address;
  //   s_axil_wdata_i = data;
  //   s_axil_wstrb_i = '1;

  //   s_axil_awvalid_i = 1;
  //   s_axil_wvalid_i = 1;
  //   wait ((s_axil_wready_o && s_axil_wvalid_i) && (s_axil_wready_o && s_axil_wvalid_i));
  //   $write("[%0t] WRITE[%p]: %0x ", $time, s_axil_awaddr_i, s_axil_wdata_i);
  //   @(negedge clk_i);
  //   s_axil_awvalid_i = 0;
  //   s_axil_wvalid_i = 0;

  //   s_axil_bready_i = 1;
  //   wait (s_axil_bready_i && s_axil_bvalid_o);
  //   if (s_axil_bresp_o == 2'b00) $write("[PASS]");
  //   else $write("[ERROR]");
  //   $display();
  //   @(negedge clk_i);
  //   s_axil_bready_i = 0;
  // endtask

  // task automatic read(
  //   input uart_addr_e address
  // );
  //   s_axil_araddr_i = address;

  //   s_axil_arvalid_i = 1;
  //   wait (s_axil_arready_o && s_axil_arvalid_i);
  //   $write("[%0t] READ[%p]: ", $time, s_axil_araddr_i);
  //   @(negedge clk_i);
  //   s_axil_arvalid_i = 0;

  //   s_axil_rready_i = 1;
  //   wait (s_axil_rready_i && s_axil_rvalid_o);
  //   if (s_axil_rresp_o == 2'b00) $write("[PASS] ");
  //   else $write("[ERROR] ");
  //   $write("s_axil_rdata_o = %0x", s_axil_rdata_o);
  //   $display();
  //   @(negedge clk_i);
  //   s_axil_rready_i = 0;
  // endtask

  task read_until_cond(
    int baud_rate,
    uart_addr_e addr,
    bit [31:0] cond
  );
    bit [26:0] tx_baud_div;
    int        clock_count;
    tx_baud_div = (baud_div_f(baud_rate) * 16);
    clock_count = 0;

    do begin
      assert (addr != INVALID_ADDR_1);
      assert (addr != INVALID_ADDR_2);

      // NOTE: Wait at most 2 of the longest frames possible
      // 2 * (1 stop, 8 bits, 1 parity, 2 stop)
      if (clock_count == 24) begin
        $display("[%0t] READ_UNTIL_COND: timeout.", $time);
        break;
      end

      read(addr);
      if ((s_axil_rdata_o & cond) != cond) begin
        repeat (tx_baud_div) @(negedge clk_i);
        clock_count++;
      end else begin
        $display("[%0t] READ_UNTIL_COND: %p = 32'b%0b", $time, addr, cond);
        break;
      end

    end while (1);
  endtask


  // TODO: Do better ???
  localparam bit [31:0] THR_VALID     = 1 << 0;
  localparam bit [31:0] RHR_READY     = 1 << 1;
  localparam bit [31:0] FRAME_ERROR   = 1 << 2;
  localparam bit [31:0] PARITY_ERROR  = 1 << 3;
  localparam bit [31:0] OVERRUN_ERROR = 1 << 4;
  localparam bit [31:0] TX_FIFO_FULL  = 1 << 5;
  localparam bit [31:0] RX_FIFO_FULL  = 1 << 6;
  localparam bit [31:0] TX_FIFO_EMPTY = 1 << 7;
  localparam bit [31:0] RX_FIFO_EMPTY = 1 << 8;

  string                word = "Hello World";

  initial begin
    // default values
    s_axil_awaddr_i  = CTRL_ADDR;
    s_axil_awprot_i  = '0;
    s_axil_awvalid_i = '0;
    s_axil_wdata_i   = '0;
    s_axil_wstrb_i   = '0;
    s_axil_wvalid_i  = '0;
    s_axil_bready_i  = '0;
    s_axil_araddr_i  = CTRL_ADDR;
    s_axil_arprot_i  = '0;
    s_axil_arvalid_i = '0;
    s_axil_rready_i  = '0;

    @(negedge reset_i);
    @(negedge clk_i);
    $display("[%0t] Simulation start.", $time);


    $display("[%0t] Read test out of reset.", $time);
    read(CTRL_ADDR);
    read(STATUS_ADDR);
    read(BAUD_DIV_ADDR);
    read(MODE_ADDR);
    read(THR_ADDR);
    read(RHR_ADDR);
    read(INVALID_ADDR_1);
    read(INVALID_ADDR_2);
    $display("[%0t] Write test.", $time);
    write(CTRL_ADDR, 15);
    write(STATUS_ADDR, 15);
    write(BAUD_DIV_ADDR, 15);
    write(MODE_ADDR, 15);
    write(THR_ADDR, 15);
    write(RHR_ADDR, 15);
    write(INVALID_ADDR_1, 15);
    write(INVALID_ADDR_2, 15);
    $display("[%0t] Read test.", $time);
    read(CTRL_ADDR);
    read(STATUS_ADDR);
    read(BAUD_DIV_ADDR);
    read(MODE_ADDR);
    read(THR_ADDR);
    read(RHR_ADDR);
    read(INVALID_ADDR_1);
    read(INVALID_ADDR_2);

    reset();

    // SEND ONE Character

    // Stop resetting uarts & FIFOs
    write(CTRL_ADDR, 0);
    write(BAUD_DIV_ADDR, baud_div_f(115200));
    write(THR_ADDR, 8'b0101_0101);

    read_until_cond(115200, STATUS_ADDR, RHR_READY);
    read(RHR_ADDR);
    assert(s_axil_rdata_o == 8'b0101_0101);

    // Send string
    foreach (word[i]) begin
      write(THR_ADDR, word[i]);
      $display("[%0t] Sent charcter %s", $time, word[i]);
    end

    // Wait a long time
    for (int i = 0; i < word.len(); i++) begin
      // Block until we receive confirmation of a character to recv or timeout
      read_until_cond(115200, STATUS_ADDR, RHR_READY);
      read(RHR_ADDR);
      $display("[%0t] Recv charcter %s", $time, s_axil_rdata_o);
    end


    repeat (10) @(negedge clk_i);
    $finish();
  end

endmodule
