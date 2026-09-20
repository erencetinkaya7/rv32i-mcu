.section .init
.globl _start
.type _start, @function

# Prepare the C runtime, enable machine timer interrupts, then call main.
_start:
    la   sp, __stack_top
    la   t0, __data_load_start
    la   t1, __data_start
    la   t2, __data_end

# Restore writable initial values on every reset.
copy_data:
    bgeu t1, t2, prepare_bss
    lw   t3, 0(t0)
    sw   t3, 0(t1)
    addi t0, t0, 4
    addi t1, t1, 4
    j    copy_data

prepare_bss:
    la   t0, __bss_start
    la   t1, __bss_end

# C expects uninitialized global variables to start at zero.
clear_bss:
    bgeu t0, t1, configure_interrupts
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    clear_bss

# Route traps to trap_entry and enable machine timer interrupts.
configure_interrupts:
    la   t0, trap_entry
    csrw mtvec, t0

    li   t0, 0x80
    csrw mie, t0

    li   t0, 0x08
    csrs mstatus, t0

    call main

# Bare-metal main should not return.
halt:
    j halt

.size _start, . - _start
