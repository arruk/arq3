#include <stdint.h>

#include "mmio.h"
#include "socfpga.h"
#include "uart.h"

#define UART_RBR_THR_DLL 0x00u
#define UART_IER_DLH     0x04u
#define UART_FCR         0x08u
#define UART_LCR         0x0Cu
#define UART_MCR         0x10u
#define UART_LSR         0x14u

#define UART_LCR_DLAB    (1u << 7)
#define UART_LCR_8N1     0x03u
#define UART_FCR_ENABLE  0x01u
#define UART_FCR_CLEAR   0x06u
#define UART_MCR_DTR_RTS 0x03u
#define UART_LSR_THRE    (1u << 5)

#ifndef HPS_UART_CLK_HZ
#define HPS_UART_CLK_HZ 100000000u
#endif

#ifndef HPS_UART_BAUD
#define HPS_UART_BAUD 115200u
#endif

static inline uint32_t uart_reg(uint32_t offset)
{
    return SOCFPGA_UART0_BASE + offset;
}

void uart_init(void)
{
    const uint32_t divisor = HPS_UART_CLK_HZ / (16u * HPS_UART_BAUD);

    mmio_write32(uart_reg(UART_IER_DLH), 0u);
    mmio_write32(uart_reg(UART_LCR), UART_LCR_DLAB);
    mmio_write32(uart_reg(UART_RBR_THR_DLL), divisor & 0xFFu);
    mmio_write32(uart_reg(UART_IER_DLH), (divisor >> 8u) & 0xFFu);
    mmio_write32(uart_reg(UART_LCR), UART_LCR_8N1);
    mmio_write32(uart_reg(UART_FCR), UART_FCR_ENABLE | UART_FCR_CLEAR);
    mmio_write32(uart_reg(UART_MCR), UART_MCR_DTR_RTS);
}

void uart_putc(char c)
{
    if (c == '\n') {
        uart_putc('\r');
    }

    while ((mmio_read32(uart_reg(UART_LSR)) & UART_LSR_THRE) == 0u) {
    }

    mmio_write32(uart_reg(UART_RBR_THR_DLL), (uint32_t)c);
}

void uart_puts(const char *s)
{
    while (*s != '\0') {
        uart_putc(*s++);
    }
}
