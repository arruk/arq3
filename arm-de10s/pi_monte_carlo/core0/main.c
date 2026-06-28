#include <stdint.h>

#include "barrier.h"
#include "mem.h"
#include "monte_carlo.h"
#include "print.h"
#include "shared_data.h"
#include "socfpga.h"
#include "uart.h"

extern const uint8_t core1_image_start[];
extern const uint8_t core1_image_end[];

static void copy_core1_image(void)
{
    const uint32_t len = (uint32_t)(core1_image_end - core1_image_start);

    mem_copy((void *)PI_CORE1_LOAD_ADDR, core1_image_start, len);
}

int main(void)
{
    volatile shared_data_t *shared = shared_data();
    const uint32_t core0_samples = PI_TOTAL_SAMPLES / 2u;
    const uint32_t core1_samples = PI_TOTAL_SAMPLES - core0_samples;

    uart_init();
    uart_puts("\nPI Monte Carlo dual-core na DE10-Standard\n");

    mem_zero((void *)shared, sizeof(*shared));
    shared->samples[0] = core0_samples;
    shared->samples[1] = core1_samples;
    shared->ready[0] = 1u;
    shared->magic = PI_SHARED_MAGIC;
    cpu_dsb();

    copy_core1_image();
    socfpga_start_cpu1(PI_CORE1_LOAD_ADDR);

    uart_puts("Aguardando core 1...\n");
    while (shared->ready[1] == 0u) {
        cpu_dmb();
    }

    shared->start = 1u;
    cpu_dsb();
    cpu_sev();

    shared->inside[0] = monte_carlo_count(core0_samples, 0x13579BDFu);
    shared->done[0] = 1u;
    cpu_dsb();

    while (shared->done[1] == 0u) {
        cpu_dmb();
    }

    const uint32_t total_inside = shared->inside[0] + shared->inside[1];
    const uint32_t total_samples = shared->samples[0] + shared->samples[1];
    const uint64_t scaled_pi =
        (4ull * (uint64_t)total_inside * 1000000ull) / total_samples;

    uart_puts("Amostras core 0: ");
    print_u32_dec(shared->samples[0]);
    uart_puts("\nAmostras core 1: ");
    print_u32_dec(shared->samples[1]);
    uart_puts("\nPontos dentro: ");
    print_u32_dec(total_inside);
    uart_puts("\nPi estimado: ");
    print_fixed_6((uint32_t)(scaled_pi / 1000000ull),
                  (uint32_t)(scaled_pi % 1000000ull));
    uart_puts("\n");

    for (;;) {
    }
}
