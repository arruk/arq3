#include <stdint.h>

#include "print.h"
#include "uart.h"

void print_u32_dec(uint32_t value)
{
    char buf[10];
    unsigned int pos = 0u;

    if (value == 0u) {
        uart_putc('0');
        return;
    }

    while (value != 0u) {
        buf[pos++] = (char)('0' + (value % 10u));
        value /= 10u;
    }

    while (pos != 0u) {
        uart_putc(buf[--pos]);
    }
}

void print_u32_hex(uint32_t value)
{
    static const char digits[] = "0123456789ABCDEF";

    uart_puts("0x");
    for (int shift = 28; shift >= 0; shift -= 4) {
        uart_putc(digits[(value >> (uint32_t)shift) & 0xFu]);
    }
}

void print_fixed_6(uint32_t integer, uint32_t frac_6)
{
    uint32_t divisor = 100000u;

    print_u32_dec(integer);
    uart_putc('.');

    while (divisor != 0u) {
        uart_putc((char)('0' + ((frac_6 / divisor) % 10u)));
        divisor /= 10u;
    }
}
