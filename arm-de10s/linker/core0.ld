ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00100000, LENGTH = 1M
}

SECTIONS
{
    . = ORIGIN(RAM);

    .text : ALIGN(4)
    {
        KEEP(*(.vectors))
        *(.text*)
        *(.rodata*)
        *(.ARM.extab*)
        *(.ARM.exidx*)
    } > RAM

    .data : ALIGN(4)
    {
        *(.data*)
    } > RAM

    .bss (NOLOAD) : ALIGN(4)
    {
        __bss_start__ = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end__ = .;
    } > RAM

    . = ALIGN(8);
    __end__ = .;
    __stack_top = ORIGIN(RAM) + LENGTH(RAM);
}
