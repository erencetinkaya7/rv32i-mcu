# RV32I MCU

A small FPGA microcontroller platform for learning how bare-metal C connects to a custom five-stage RV32I processor, memory-mapped peripherals, simulation, and real hardware.

The processor base comes from the verified `rv32i-pipelined` project at commit `40901f3`.

## Current checkpoint

- Minimal C startup code and linker script
- Separate instruction and data memory images
- GPIO, timer, UART TX, and UART RX through memory-mapped I/O
- Machine timer interrupts with an assembly context wrapper and C handler
- Non-blocking C superloop with an interactive UART command interface
- Self-checking full-SoC simulation
- Tang Nano 9K synthesis, timing, and physical FPGA test

## Use

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

After flashing, open the UART monitor and press the board reset button. The board prints `C IRQ READY` and starts moving the LEDs. LED timing is driven by machine timer interrupts.

| Key | Action | Reply |
|---|---|---|
| `p` | Pause or resume the LED animation | `PAUSED` / `RUNNING` |
| `r` | Reset the LED pattern | `RESET` |
| `+` | Select the next faster step | `FASTER` |
| `-` | Select the next slower step | `SLOWER` |
| other | Echo the received byte | same byte |

## Timer interrupt path

The timer raises a machine timer interrupt when its counter expires. The CPU records the interrupted PC and cause, jumps through `mtvec` to `trap_entry`, and saves the caller-saved registers. The C handler records the event and reloads the timer; `mret` then resumes the interrupted code. The main loop sees the new event count and advances the GPIO pattern when the animation is not paused.

`make test` checks the complete path, including the expected interrupt cause, handler return, UART commands, timer reload values, and GPIO behavior.

## Layout

```text
rtl/       Processor, pipeline, memories, peripherals, and SoC
software/  Startup code, linker script, MMIO definitions, and C programs
tests/     Self-checking SoC simulation
fpga/      Tang Nano 9K top level and pin constraints
scripts/   Binary conversion and interactive UART terminal
```
