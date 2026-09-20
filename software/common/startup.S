.section .init
.globl _start
.type _start, @function

# Prepare the C runtime, then call main.
_start:
    la   sp, __stack_top
    la   t0, __bss_start
    la   t1, __bss_end

# C expects uninitialized global variables to start at zero.
clear_bss:
    bgeu t0, t1, call_main
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    clear_bss

call_main:
    call main

# Bare-metal main should not return.
halt:
    j halt

.size _start, . - _start
