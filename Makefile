.DEFAULT_GOAL := software

CROSS ?= riscv64-unknown-elf-
CC      := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
OBJDUMP := $(CROSS)objdump
SIZE    := $(CROSS)size
PYTHON ?= /usr/bin/python3

BUILD         := build
SOFTWARE_BUILD := $(BUILD)/software
COMMON_DIR    := software/common
APP_DIR       := software/examples/bringup

STARTUP_SRC := $(COMMON_DIR)/startup.S
MAIN_SRC    := $(APP_DIR)/main.c
LINKER      := $(COMMON_DIR)/linker.ld
TRAP_SRC    := $(COMMON_DIR)/trap_entry.S

STARTUP_OBJ := $(SOFTWARE_BUILD)/startup.o
MAIN_OBJ    := $(SOFTWARE_BUILD)/main.o
TRAP_OBJ    := $(SOFTWARE_BUILD)/trap_entry.o
TIMER_CONFIG := $(SOFTWARE_BUILD)/timer_ticks.txt
ELF         := $(SOFTWARE_BUILD)/bringup.elf
IMEM_BIN    := $(SOFTWARE_BUILD)/imem.bin
DMEM_BIN    := $(SOFTWARE_BUILD)/dmem.bin
MAP         := $(SOFTWARE_BUILD)/bringup.map
DIS         := $(SOFTWARE_BUILD)/bringup.dis
IMEM_HEX    := $(SOFTWARE_BUILD)/imem.hex
DMEM_HEX    := $(SOFTWARE_BUILD)/dmem.hex

ARCH ?= rv32i_zicsr
ABI  ?= ilp32
TIMER_TICKS ?= 1000

ARCH_FLAGS := -march=$(ARCH) -mabi=$(ABI) -mstrict-align -mno-relax

CPPFLAGS = -I$(COMMON_DIR) -DTIMER_TICKS=$(TIMER_TICKS)

CFLAGS := $(ARCH_FLAGS) \
	-std=c11 \
	-Os \
	-ffreestanding \
	-fno-builtin \
	-fno-pic \
	-fno-common \
	-fno-stack-protector \
	-fstack-usage \
	-fno-unwind-tables \
	-fno-asynchronous-unwind-tables \
	-ffunction-sections \
	-fdata-sections \
	-Wall \
	-Wextra

ASFLAGS := $(ARCH_FLAGS) -x assembler-with-cpp

LDFLAGS := $(ARCH_FLAGS) \
	-nostdlib \
	-nostartfiles \
	-Wl,-T,$(LINKER) \
	-Wl,-Map,$(MAP) \
	-Wl,--gc-sections \
	-Wl,--no-relax \
	-Wl,--build-id=none

.PHONY: software inspect clean help

software: $(ELF) $(IMEM_BIN) $(DMEM_BIN) $(DIS) $(IMEM_HEX) $(DMEM_HEX)
	@echo "Software ready: $(ELF)"

$(STARTUP_OBJ): $(STARTUP_SRC) $(LINKER)
	@mkdir -p $(SOFTWARE_BUILD)
	$(CC) $(CPPFLAGS) $(ASFLAGS) -c $< -o $@

$(TRAP_OBJ): $(TRAP_SRC) $(LINKER)
	@mkdir -p $(SOFTWARE_BUILD)
	$(CC) $(CPPFLAGS) $(ASFLAGS) -c $< -o $@

$(TIMER_CONFIG): FORCE
	@mkdir -p $(SOFTWARE_BUILD)
	@if [ ! -f "$@" ] || [ "$$(cat "$@")" != "$(TIMER_TICKS)" ]; then \
		echo "$(TIMER_TICKS)" > "$@"; \
	fi

$(MAIN_OBJ): $(MAIN_SRC) $(COMMON_DIR)/mmio.h $(TIMER_CONFIG) Makefile
	@mkdir -p $(SOFTWARE_BUILD)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(ELF): $(STARTUP_OBJ) $(TRAP_OBJ) $(MAIN_OBJ) $(LINKER)
	$(CC) $(LDFLAGS) $(STARTUP_OBJ) $(TRAP_OBJ) $(MAIN_OBJ) -o $@
	$(SIZE) $@

$(IMEM_BIN): $(ELF)
	$(OBJCOPY) -O binary --only-section=.text $< $@

$(DMEM_BIN): $(ELF) Makefile
	$(OBJCOPY) -O binary --only-section=.rodata --only-section=.data $< $@

$(DIS): $(ELF)
	$(OBJDUMP) -d -M no-aliases $< > $@

$(IMEM_HEX): $(IMEM_BIN) scripts/bin_to_hex.py Makefile
	$(PYTHON) scripts/bin_to_hex.py $< $@ \
		--words 1024 \
		--fill 0x00000013 \
		--strict-word-alignment
	@touch $@

$(DMEM_HEX): $(DMEM_BIN) scripts/bin_to_hex.py Makefile
	$(PYTHON) scripts/bin_to_hex.py $< $@ \
		--words 256 \
		--fill 0x00000000
	@touch $@

inspect: software
	@echo "== Sections =="
	$(OBJDUMP) -h $(ELF)
	@echo
	@echo "== Disassembly =="
	@sed -n '1,220p' $(DIS)

clean:
	rm -rf $(BUILD)

help:
	@echo "Run from the repository root:"
	@echo "  make software             Compile and link the C program"
	@echo "  make inspect              Show ELF sections and RV32I disassembly"
	@echo "  make test                 Run all four checks with PASS/FAIL totals"
	@echo "  make test-stack            Check linker stack-reservation boundary"
	@echo "  make test-runtime          Check C initial values across reset"
	@echo "  make test-c                Run the C/SoC integration test"
	@echo "  make test-memory           Check memory addresses and RAM boundaries"
	@echo "  make wave                 Run regression and open the C/SoC waveform"
	@echo "  make fpga                 Build the Tang Nano 9K bitstream"
	@echo "  make flash                Build and load volatile FPGA SRAM"
	@echo "  make uart-ports           List available serial ports"
	@echo "  make uart-monitor         Open the interactive UART terminal"
	@echo "  make clean                Remove generated build outputs"
	@echo "  make help                 Show this command list"
	@echo
	@echo "Optional override:"
	@echo "  make software TIMER_TICKS=20"


# Complete SoC simulation for the C bring-up program.
IVERILOG ?= iverilog
VVP      ?= vvp

RTL := rtl/core/*.sv rtl/pipeline/*.sv rtl/memory/*.sv \
	rtl/peripherals/*.sv rtl/soc/*.sv

SIM_BUILD := $(BUILD)/sim
LOG_DIR   := $(BUILD)/logs
WAVE_DIR  := $(BUILD)/waves
WAVE_FILE := $(WAVE_DIR)/c_bringup.vcd
TEST_SIM  := $(SIM_BUILD)/c_bringup_tb_sim
TEST_LOG  := $(LOG_DIR)/c_bringup_tb.log

.PHONY: test test-c FORCE

# Track TIMER_TICKS so software rebuilds only when the selected profile changes.
FORCE:


# Count test targets, including build failures, and always run every test.
test:
	@passed=0; failed=0; \
	for target in test-memory test-c test-runtime test-stack; do \
		if $(MAKE) --no-print-directory $$target; then \
			passed=$$((passed + 1)); \
		else \
			failed=$$((failed + 1)); \
		fi; \
	done; \
	echo "Summary: $$passed PASS, $$failed FAIL"; \
	test $$failed -eq 0

test-c: TIMER_TICKS=256
test-c: software $(TEST_SIM)
	@mkdir -p $(LOG_DIR) $(WAVE_DIR)
	@$(VVP) $(TEST_SIM) > $(TEST_LOG) 2>&1 || { cat $(TEST_LOG); exit 1; }
	@cat $(TEST_LOG)
	@grep -q "PASS" $(TEST_LOG)

$(TEST_SIM): tests/c_bringup_tb.sv $(wildcard $(RTL)) $(IMEM_HEX) $(DMEM_HEX)
	@mkdir -p $(SIM_BUILD)
	$(IVERILOG) -g2012 -s c_bringup_tb -o $@ $(RTL) $<


.PHONY: wave

wave: test
	gtkwave $(WAVE_FILE)
# Tang Nano 9K FPGA build and board tools.
OSS_CAD_DIR ?= $(HOME)/oss-cad-suite
export PATH := $(OSS_CAD_DIR)/bin:$(PATH)

YOSYS            ?= yosys
NEXTPNR          ?= nextpnr-himbaechel
GOWIN_PACK       ?= gowin_pack
OPENFPGALOADER   ?= openFPGALoader

FPGA_DIR       := fpga/tangnano9k
FPGA_BUILD     := $(BUILD)/fpga
FPGA_JSON      := $(FPGA_BUILD)/rv32i_mcu.json
FPGA_PNR_JSON  := $(FPGA_BUILD)/rv32i_mcu_pnr.json
FPGA_BITSTREAM := $(FPGA_BUILD)/rv32i_mcu.fs

UART_PORT ?= /dev/ttyUSB1
UART_BAUD ?= 115200

.PHONY: fpga flash uart-monitor uart-ports

# Half a second per LED step at the 27 MHz board clock.
fpga: TIMER_TICKS=13500000
fpga: $(FPGA_BITSTREAM)
	@echo "FPGA image ready: $(FPGA_BITSTREAM)"

$(FPGA_JSON): $(wildcard $(RTL)) $(FPGA_DIR)/top.sv $(IMEM_HEX) $(DMEM_HEX) $(DIS)
	@mkdir -p $(FPGA_BUILD)
	$(YOSYS) -p "read_verilog -sv $(RTL) $(FPGA_DIR)/top.sv; synth_gowin -top top -json $@"

$(FPGA_PNR_JSON): $(FPGA_JSON) $(FPGA_DIR)/tangnano9k.cst
	$(NEXTPNR) --json $< --write $@ \
		--device GW1NR-LV9QN88PC6/I5 \
		--freq 27 \
		--seed 30 \
		--vopt family=GW1N-9C \
		--vopt cst=$(FPGA_DIR)/tangnano9k.cst

$(FPGA_BITSTREAM): $(FPGA_PNR_JSON)
	$(GOWIN_PACK) -d GW1N-9C -o $@ $<

flash: fpga
	$(OPENFPGALOADER) -b tangnano9k $(FPGA_BITSTREAM)

uart-ports:
	$(PYTHON) -m serial.tools.list_ports -v

uart-monitor:
	$(PYTHON) scripts/uart_monitor.py \
		--port $(UART_PORT) \
		--baud $(UART_BAUD)

# Isolated memory/address-decoder checks; no C program is required.
.PHONY: test-memory
test-memory: $(SIM_BUILD)/memory_map_tb_sim
	@mkdir -p $(LOG_DIR)
	@$(VVP) $< > $(LOG_DIR)/memory_map_tb.log 2>&1 || { cat $(LOG_DIR)/memory_map_tb.log; exit 1; }
	@cat $(LOG_DIR)/memory_map_tb.log
	@grep -q "PASS" $(LOG_DIR)/memory_map_tb.log

$(SIM_BUILD)/memory_map_tb_sim: tests/memory_map_tb.sv $(wildcard $(RTL))
	@mkdir -p $(SIM_BUILD)
	$(IVERILOG) -g2012 -s memory_map_tb -o $@ $(RTL) $<

# Build the runtime example separately from the interactive board program.
.PHONY: runtime-software test-runtime
runtime-software:
	$(MAKE) --no-print-directory software APP_DIR=software/examples/runtime_check SOFTWARE_BUILD=build/runtime

test-runtime: runtime-software $(SIM_BUILD)/c_runtime_tb_sim
	@mkdir -p $(LOG_DIR)
	@$(VVP) $(SIM_BUILD)/c_runtime_tb_sim > $(LOG_DIR)/c_runtime_tb.log 2>&1 || { cat $(LOG_DIR)/c_runtime_tb.log; exit 1; }
	@cat $(LOG_DIR)/c_runtime_tb.log
	@grep -q "PASS" $(LOG_DIR)/c_runtime_tb.log

$(SIM_BUILD)/c_runtime_tb_sim: tests/c_runtime_tb.sv $(wildcard $(RTL))
	@mkdir -p $(SIM_BUILD)
	$(IVERILOG) -g2012 -s c_runtime_tb -o $@ $(RTL) $<

# 768 bytes fit below the stack; one extra byte must be rejected.
.PHONY: test-stack
test-stack:
	@mkdir -p $(BUILD)/stack-check $(LOG_DIR)
	@$(CC) $(ASFLAGS) -DBSS_BYTES=768 -c tests/stack_layout.S -o $(BUILD)/stack-check/fits.o
	@$(CC) $(ASFLAGS) -DBSS_BYTES=769 -c tests/stack_layout.S -o $(BUILD)/stack-check/overlap.o
	@$(CC) $(ARCH_FLAGS) -nostdlib -Wl,-T,$(LINKER) -Wl,--build-id=none $(BUILD)/stack-check/fits.o -o $(BUILD)/stack-check/fits.elf
	@if $(CC) $(ARCH_FLAGS) -nostdlib -Wl,-T,$(LINKER) -Wl,--build-id=none $(BUILD)/stack-check/overlap.o -o $(BUILD)/stack-check/overlap.elf > $(LOG_DIR)/stack_overlap.log 2>&1; then \
		echo "FAIL: linker accepted data overlapping the stack"; exit 1; \
	fi
	@grep -q "Static data overlaps reserved stack" $(LOG_DIR)/stack_overlap.log || { cat $(LOG_DIR)/stack_overlap.log; exit 1; }
	@echo "PASS: linker accepts the boundary and rejects stack overlap"
