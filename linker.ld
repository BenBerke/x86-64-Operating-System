ENTRY(_start)

SECTIONS
{
    . = 0x10000;

    /* One output section, so PE alignment can't put gaps between code and data */
    .text : {
        KEEP(*(.text.start))
        *(.text*)
        *(.rdata*)
        *(.rodata*)
        *(.data*)
        *(.bss*)
        *(COMMON)
        . = ALIGN(16);
    }

    /DISCARD/ : {
        *(.pdata*)
        *(.xdata*)
        *(.eh_frame*)
        *(.comment)
        *(.note*)
        *(.drectve)
    }
}