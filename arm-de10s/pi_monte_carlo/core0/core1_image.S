    .section .rodata.core1_image, "a"
    .balign 4
    .global core1_image_start
    .global core1_image_end

core1_image_start:
    .incbin CORE1_BIN_PATH
core1_image_end:
    .balign 4
