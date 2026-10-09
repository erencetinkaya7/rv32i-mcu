.section .text
.globl _start

# The testbench supplies enable values through a tiny mock data interface.
_start:
    li a0, 0
main_loop:
    lw t1, 0(zero)          # Requested mie value.
    csrw mie, t1
    lw t1, 4(zero)          # Requested global MIE value.
    csrw mstatus, t1
    addi a0, a0, 1          # Main must keep progressing after MRET.
    j main_loop

.org 0x80
trap_handler:
    csrr t3, mcause
    sw t3, 12(zero)         # Report the cause to the testbench.
    sw zero, 16(zero)       # Ask the mock external source to clear.
    mret
    sw zero, 20(zero)       # Wrong path: this store must be flushed.
