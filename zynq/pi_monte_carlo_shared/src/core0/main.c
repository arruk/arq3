#include "monte_carlo.h"
#include "shared_data.h"
#include "xil_cache.h"
#include "xil_printf.h"
#include "xtime_l.h"

static void print_six_digits(u32 value)
{
    u32 divisor;

    for (divisor = 100000U; divisor > 0U; divisor /= 10U) {
        xil_printf("%c", (char)('0' + ((value / divisor) % 10U)));
    }
}

int main(void)
{
    shared_data_t *shared = shared_data();
    const u32 core0_samples = TOTAL_SAMPLES / 2U;
    const u32 core1_samples = TOTAL_SAMPLES - core0_samples;
    u64 scaled_pi;
    u32 total_inside;
    u32 total_samples;
    XTime start_time;
    XTime end_time;
    u64 elapsed_ms;

    Xil_DCacheDisable();

    shared->magic = 0U;
    shared->start = 0U;
    shared->ready[0] = 0U;
    shared->ready[1] = 0U;
    shared->done[0] = 0U;
    shared->done[1] = 0U;
    shared->samples[0] = core0_samples;
    shared->samples[1] = core1_samples;
    shared->inside[0] = 0U;
    shared->inside[1] = 0U;

    shared->ready[0] = 1U;
    shared_memory_barrier();
    shared->magic = SHARED_MAGIC;
    shared_memory_barrier();

    while (shared->ready[1] == 0U) {
        shared_memory_barrier();
    }

    XTime_GetTime(&start_time);
    shared->start = 1U;
    shared_memory_barrier();

    shared->inside[0] = monte_carlo_count(core0_samples, 0x13579BDFU);
    shared->done[0] = 1U;
    shared_memory_barrier();

    while (shared->done[1] == 0U) {
        shared_memory_barrier();
    }
    XTime_GetTime(&end_time);

    total_inside = shared->inside[0] + shared->inside[1];
    total_samples = shared->samples[0] + shared->samples[1];
    scaled_pi = (4ULL * total_inside * 1000000ULL) / total_samples;
    elapsed_ms = ((end_time - start_time) * 1000ULL) / COUNTS_PER_SECOND;

    xil_printf("\r\nPI por Monte Carlo com dois Cortex-A9\r\n");
    xil_printf("Amostras core 0: %u\r\n", shared->samples[0]);
    xil_printf("Amostras core 1: %u\r\n", shared->samples[1]);
    xil_printf("Pontos dentro: %u\r\n", total_inside);
    xil_printf("PI estimado: %u.", (u32)(scaled_pi / 1000000ULL));
    print_six_digits((u32)(scaled_pi % 1000000ULL));
    xil_printf("\r\nTempo: %u ms\r\n", (u32)elapsed_ms);

    return 0;
}

