# RV32I MCU

A small RV32I microcontroller platform for learning bare-metal C, memory-mapped I/O, interrupts, and FPGA integration.

## Goal

Run C programs on a custom five-stage RV32I processor and connect software behavior to RTL, simulation, and physical FPGA results.

## Hardware base

The processor starts from the verified `rv32i-pipelined` checkpoint at commit `40901f3`.

## Planned first checkpoint

- Minimal startup code
- Linker script
- GPIO and UART access from C
- Self-checking simulation
- Tang Nano 9K demonstration

## Status

Initial project setup.
