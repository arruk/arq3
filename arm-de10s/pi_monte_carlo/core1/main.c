#include <stdint.h>

#include "barrier.h"
#include "monte_carlo.h"
#include "shared_data.h"
#include "socfpga.h"

int main(void)
{
    volatile shared_data_t *shared = shared_data();

    while (shared->magic != PI_SHARED_MAGIC) {
        cpu_wfe();
        cpu_dmb();
    }

    shared->ready[1] = 1u;
    cpu_dsb();
    cpu_sev();

    while (shared->start == 0u) {
        cpu_wfe();
        cpu_dmb();
    }

    shared->inside[1] =
        monte_carlo_count(shared->samples[1], 0x2468ACE1u);
    shared->done[1] = 1u;
    cpu_dsb();
    cpu_sev();

    socfpga_park_current_cpu();
}
