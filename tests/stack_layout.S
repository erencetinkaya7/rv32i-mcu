# Link-only fixture: vary BSS size to check the reserved stack boundary.
.section .init
.globl _start
_start:
    j _start

.section .bss
.balign 4
.space BSS_BYTES
