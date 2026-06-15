#include "monte_carlo.h"
#include "shared_data.h"
#include "xil_cache.h"

int main(void)
{
    shared_data_t *shared = shared_data();
    u32 samples;

    Xil_DCacheDisable();

    while (shared->magic != SHARED_MAGIC) {
        shared_memory_barrier();
    }

    samples = shared->samples[1];
    shared->ready[1] = 1U;
    shared_memory_barrier();

    while (shared->start == 0U) {
        shared_memory_barrier();
    }

    shared->inside[1] = monte_carlo_count(samples, 0x2468ACE1U);
    shared->done[1] = 1U;
    shared_memory_barrier();

    return 0;
}

