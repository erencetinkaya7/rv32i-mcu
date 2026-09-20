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

STARTUP_OBJ := $(SOFTWARE_BUILD)/startup.o
MAIN_OBJ    := $(SOFTWARE_BUILD)/main.o
TIMER_CONFIG := $(SOFTWARE_BUILD)/timer_ticks.txt
ELF         := $(SOFTWARE_BUILD)/bringup.elf
IMEM_BIN    := $(SOFTWARE_BUILD)/imem.bin
DMEM_BIN    := $(SOFTWARE_BUILD)/dmem.bin
MAP         := $(SOFTWARE_BUILD)/bringup.map
DIS         := $(SOFTWARE_BUILD)/bringup.dis
IMEM_HEX    := $(SOFTWARE_BUILD)/imem.hex
DMEM_HEX    := $(SOFTWARE_BUILD)/dmem.hex

ARCH ?= rv32i
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

$(TIMER_CONFIG): FORCE
	@mkdir -p $(SOFTWARE_BUILD)
	@if [ ! -f "$@" ] || [ "$$(cat "$@")" != "$(TIMER_TICKS)" ]; then \
		echo "$(TIMER_TICKS)" > "$@"; \
	fi

$(MAIN_OBJ): $(MAIN_SRC) $(COMMON_DIR)/mmio.h $(TIMER_CONFIG)
	@mkdir -p $(SOFTWARE_BUILD)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(ELF): $(STARTUP_OBJ) $(MAIN_OBJ) $(LINKER)
	$(CC) $(LDFLAGS) $(STARTUP_OBJ) $(MAIN_OBJ) -o $@
	$(SIZE) $@

$(IMEM_BIN): $(ELF)
	$(OBJCOPY) -O binary --only-section=.text $< $@

$(DMEM_BIN): $(ELF)
	$(OBJCOPY) -O binary --only-section=.rodata $< $@

$(DIS): $(ELF)
	$(OBJDUMP) -d -M no-aliases $< > $@

$(IMEM_HEX): $(IMEM_BIN) scripts/bin_to_hex.py
	$(PYTHON) scripts/bin_to_hex.py $< $@ \
		--words 256 \
		--fill 0x00000013 \
		--strict-word-alignment
	@touch $@

$(DMEM_HEX): $(DMEM_BIN) scripts/bin_to_hex.py
	$(PYTHON) scripts/bin_to_hex.py $< $@ \
		--words 64 \
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
	@echo "  make test                 Run the self-checking SoC simulation"
	@echo "  make wave                 Run the test and open GTKWave"
	@echo "  make fpga                 Build the Tang Nano 9K bitstream"
	@echo "  make flash                Build if needed and program the FPGA"
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

.PHONY: test FORCE

# Track TIMER_TICKS so software rebuilds only when the selected profile changes.
FORCE:


test: TIMER_TICKS=8
test: software $(TEST_SIM)
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
