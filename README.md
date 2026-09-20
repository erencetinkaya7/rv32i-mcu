# RV32I MCU

A small FPGA microcontroller platform for learning how bare-metal C connects to a custom five-stage RV32I processor, memory-mapped peripherals, simulation, and real hardware.

The processor base comes from the verified `rv32i-pipelined` project at commit `40901f3`.

## Current checkpoint

- Minimal C startup code and linker script
- Separate instruction and data memory images
- GPIO, timer, UART TX, and UART RX through memory-mapped I/O
- C program that prints `C READY`, drives the LEDs, and echoes received bytes
- Self-checking full-SoC simulation
- Tang Nano 9K synthesis, timing, and physical FPGA test

## Commands

Run everything from the repository root:

```bash
make help
make test
make wave
make fpga
make flash
make uart-ports
make uart-monitor UART_PORT=/dev/ttyUSB1
```

After flashing, press reset. The UART monitor should print `C READY`, typed characters should be echoed by the board, and the LEDs should keep moving.

## Layout

```text
rtl/       Processor, pipeline, memories, peripherals, and SoC
software/  Startup code, linker script, MMIO definitions, and C programs
tests/     Self-checking SoC simulation
fpga/      Tang Nano 9K top level and pin constraints
scripts/   Binary conversion and UART monitor tools
```
