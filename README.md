# Yet Another Uart (WIP)
NOTE: This project is still in a Work In Progress state until I am
satisfied (tested as far as my skills allow me to). There may be
things missing such as Testing of critical functionality &
Documentation.

## Introduction
This project implements an AXI4 Lite UART peripheral in SystemVerilog
using Vivado 2025.2. The implementation lacks DMA or Interrupts and
requires Polling from a user for correct operation.

Testbenches for individual components are also included.

## Documentation
TODO: See uart-doc.pdf for a detailed explanation.

### uart.sv
AXI4 Lite UART peripheral.

### uart_registers.sv
Registers used for Control & Status of the peripheral of which there
are 6.

### fifo_fwft.sv
First Word Fall Through FIFO, appropriate for ready-valid handshaking
scheme.

### uart_tx_core.sv
Transmitter UART.

### uart_rx_core.sv
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
