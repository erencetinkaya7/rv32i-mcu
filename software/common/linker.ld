OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 4K
    DMEM (rw)  : ORIGIN = 0x00010000, LENGTH = 1K
}

SECTIONS
{
    .text :
    {
        KEEP(*(.init))
        KEEP(*(.trap))
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

    /* Keep an initial-value copy before the writable .data area. */
    __data_load_start = ALIGN(ADDR(.rodata) + SIZEOF(.rodata), 4);
    .data (__data_load_start + SIZEOF(.data)) : AT(__data_load_start)
    {
        __data_start = .;
        *(.data)
        *(.data.*)
        *(.sdata)
        *(.sdata.*)
        . = ALIGN(4);
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

    /* Reserve the top 256 bytes for calls and interrupt context. */
    __stack_size = 256;
    __stack_top = ORIGIN(DMEM) + LENGTH(DMEM);
    __stack_bottom = __stack_top - __stack_size;

    ASSERT(__bss_end <= __stack_bottom,
           "Static data overlaps reserved stack")

    /DISCARD/ :
    {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
    }
}
