# Yet Another Uart (WIP)
## Introduction
This project implements an AXI4 Lite UART peripheral in SystemVerilog
using Vivado 2025.2. The implementation lacks DMA or Interrupts and
requires Polling from a user for correct operation.

Testbenches for individual components are also included.

## Operation
The peripheral contains the following register layout. Any bits in a
register not specified below do not affect operation of the
peripheral. NOTE: R = Read only, RW = Read & Write.


RW | ADDR 0: CTRL[3:0] | [reset_rx_uart, reset_tx_uart, reset_rx_fifo, reset_tx_fifo]

R | ADDR 1: STATUS[8:5] = [rx_fifo_empty, tx_fifo_empty, rx_fifo_full, tx_fifo_full]<br>
R | ADDR 1: STATUS[4:0] = [overrun_error, parity_error, frame_error, rhr_ready, thr_valid]

RW | ADDR 2: BAUD_DIV[26:0] = [baud_div[26:0]]

RW | ADDR 3: MODE[4:0] = [stops, parity_type, parity_mode, data_width[1:0]]

RW | ADDR 4: THR[7:0] = [thr_data[7:0]]

R | ADDR 5: RHR[7:0] = [rhr_data[7:0]]


### On chooosing a baud divisor
Use the following equation for setting BAUD_DIV register, baud_div =
f_clk/(16 * baud_rate).

The receiver uart uses this value by counting from 0 to
(baud_div-1) to sample the incoming data.

The transmitter uart uses the baud_div value bu counting from 0 to
(baud_div << 4) - 1.

When using both uart's as in the case of uart.sv some values of
baud_div will cause overflows and underflows. A valid baud_div value
for the receiver lies in the range between (inclusive) 2^27-1 and 1, 0
will cause and underflow. A valid baud_div value for the transmitter
is odder, values of baud_div whose result is Zero after the left shift
by 4 will cause and underflow due to the subsequent subtraction
by 1. This leaves some 16 values that cause underflows, e.g
27'bxxxx_0000..000, where xxxx are the top 4 bits of the config_i.

Thus when using both uart's (tx and rx) your baud_div must lie in a
valid range for both.

## Components
### [uart.sv](./rtl/uart.sv)
AXI4 Lite UART peripheral.

### [uart_registers.sv](./rtl/uart_registers.sv)
Registers used for Control & Status of the peripheral of which there
are 6.

### [fifo_fwft.sv](./rtl/fifo_fwft.sv)
First Word Fall Through FIFO, appropriate for ready-valid handshaking
scheme.

### [uart_tx_core.sv](./rtl/uart_tx_core.sv)
Transmitter UART.

### [uart_rx_core.sv](./rtl/uart_rx_core.sv)
Receiver UART.

## References
The following are links to projects that inspired me and links I found
useful in my learning.

- [Which comes first: the CPU or the peripherals?](https://zipcpu.com/zipcpu/2017/05/20/which-came-first.html)
- [Universal asynchronous receiver-transmitter](https://en.wikipedia.org/wiki/Universal_asynchronous_receiver-transmitter)
- [Basics of UART Communication](https://www.circuitbasics.com/basics-uart-communication/)
- [UART: A Hardware Communication Protocol Understanding Universal Asynchronous Receiver/Transmitter
](https://www.analog.com/en/resources/analog-dialogue/articles/uart-a-hardware-communication-protocol.html)
- [FPGA FIFOs: From an introduction to advanced topics](https://www.01signal.com/using-ip/fpga-fifo/)
- [Implementation of single clock FIFOs in Verilog](https://www.01signal.com/using-ip/fpga-fifo/single-clock-fifo-code/)
- [21.6.2.3 Clock Generation – Baud-Rate Generator](https://onlinedocs.microchip.com/oxy/GUID-A9964E93-D46C-42E6-98D2-4ED783ABB2CE-en-US-2/GUID-8EEBE5D7-A5B5-4174-BE64-C69BB9C16EF1.html)
- [UART 16550 IP Datasheet](https://pdos.csail.mit.edu/6.S081/2024/lec/16550.pdf)
