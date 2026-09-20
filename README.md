# RV32I MCU

A small FPGA microcontroller for learning how bare-metal C runs on a custom five-stage RISC-V processor.

The processor base comes from the verified `rv32i-pipelined` project at commit `40901f3`. Firmware targets RV32I with Zicsr for CSR access.

## Current checkpoint

- 4 KiB instruction memory and 1 KiB data memory
- C startup that restores .data and clears .bss on every reset
- GPIO, UART TX/RX, and a timer through memory-mapped I/O
- Machine timer interrupts with an assembly entry wrapper and C handler
- Interactive UART/LED application; UART reception is still polled

## Use

Run commands from the repository root:

```bash
make help
make test
make fpga
make flash
make uart-ports
make uart-monitor UART_PORT=/dev/ttyUSB1
```

`make flash` builds the interactive program and loads the FPGA's volatile configuration SRAM. The configuration is lost when power is removed.

Open the UART monitor and press the physical reset button. The board prints `C IRQ READY` and moves the LEDs every half second.

| Key | Action | Reply |
|---|---|---|
| `p` | Pause or resume | `PAUSED` / `RUNNING` |
| `r` | Return the LED pattern to its first position | `RESET` |
| `+` | Faster, down to 0.125 seconds per step | `FASTER` |
| `-` | Slower, up to 2 seconds per step | `SLOWER` |
| other | Echo the received byte | same byte |

Speed can change while paused. Physical reset restores the initial speed and restarts the program.

## Programs and memory

`software/examples/bringup/main.c` is the interactive board application. The separate `runtime_check/main.c` example tests C initialization and reset using images in `build/runtime`.

Instruction memory holds code. Data memory holds constants, a saved copy of initial values, writable .data, .bss, and the stack. Startup restores .data from the saved copy before entering main. The copy is in RAM and has no hardware write protection.

The top 256 bytes of RAM are reserved for the stack. The linker rejects static data overlapping this reserve; runtime stack overflow is not detected. GCC reports individual C function stack usage in `main.su` beside each program's objects. The interrupt wrapper adds a 64-byte frame.

## Verification

`make test` runs all four checks and prints PASS/FAIL totals. These are MCU integration tests, not the full instruction/hazard regression from the original processor project.

| Command | Checks |
|---|---|
| `make test-memory` | Expanded addresses, byte/halfword access, RAM boundaries |
| `make test-c` | UART commands, GPIO, timer interrupts, MRET, reset speed |
| `make test-runtime` | .data scalars/arrays and .bss across reset |
| `make test-stack` | Linker acceptance and rejection at the stack boundary |

Logs are in `build/logs`. `make wave` runs the regression and opens the C/SoC waveform.

This checkpoint passed all four tests, synthesis, and timing at 27 MHz (post-route estimate: 41.44 MHz). UART, LED controls, and restoration of the initial speed after reset were also verified on a Tang Nano 9K.

## Layout

```text
rtl/       Processor, pipeline, memories, peripherals, and SoC
software/  Common runtime and separate C examples
tests/     Simulation tests and linker boundary fixture
fpga/      Tang Nano 9K top level and pin constraints
scripts/   Binary conversion and interactive UART terminal
build/     Generated programs, simulations, logs, and FPGA image
```
