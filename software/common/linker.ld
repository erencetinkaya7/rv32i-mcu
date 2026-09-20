OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 1K
    DMEM (rw)  : ORIGIN = 0x00010000, LENGTH = 256
}

SECTIONS
{
    .text :
    {
        KEEP(*(.init))
        *(.text)
        *(.text.*)
    } > IMEM

    .rodata :
    {
        *(.rodata)
        *(.rodata.*)
        *(.srodata)
        *(.srodata.*)
    } > DMEM

    .data :
    {
        __data_start = .;
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
        __data_end = .;
    } > DMEM

    .bss (NOLOAD) :
    {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > DMEM

    __stack_top = ORIGIN(DMEM) + LENGTH(DMEM);

    ASSERT(SIZEOF(.data) == 0,
           "Initialized writable data is not supported yet")
    ASSERT(__bss_end <= __stack_top,
           "Data RAM overflow")

    /DISCARD/ :
    {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}
