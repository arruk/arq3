    .section .vectors, "ax"
    .global _start
    .type _start, %function

_start:
    cpsid   if

    mrc     p15, 0, r0, c1, c0, 0
    ldr     r1, =((1 << 12) | (1 << 2) | (1 << 0))
    bic     r0, r0, r1
    mcr     p15, 0, r0, c1, c0, 0
    isb

    ldr     sp, =__stack_top
    bic     sp, sp, #7

    ldr     r0, =__bss_start__
    ldr     r1, =__bss_end__
    mov     r2, #0

1:
    cmp     r0, r1
    bhs     2f
    str     r2, [r0], #4
    b       1b

2:
    bl      main

3:
    wfe
    b       3b

    .size _start, . - _start
