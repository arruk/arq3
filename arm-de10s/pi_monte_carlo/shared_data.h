#ifndef SHARED_DATA_H
#define SHARED_DATA_H

#include <stdint.h>

#include "socfpga.h"

#define PI_SHARED_MAGIC 0x50494D43u
#define PI_TOTAL_SAMPLES 2000000u

typedef struct {
    volatile uint32_t magic;
    volatile uint32_t start;
    volatile uint32_t ready[2];
    volatile uint32_t done[2];
    volatile uint32_t samples[2];
    volatile uint32_t inside[2];
} shared_data_t;

static inline volatile shared_data_t *shared_data(void)
{
    return (volatile shared_data_t *)SOCFPGA_OCRAM_BASE;
}

#endif
