#ifndef SHARED_DATA_H
#define SHARED_DATA_H

#include "xil_types.h"

#define SHARED_BRAM_BASE 0x40000000U
#define SHARED_MAGIC 0x50494D43U
#define TOTAL_SAMPLES 1000000U

typedef struct {
    volatile u32 magic;
    volatile u32 start;
    volatile u32 ready[2];
    volatile u32 done[2];
    volatile u32 samples[2];
    volatile u32 inside[2];
} shared_data_t;

static inline shared_data_t *shared_data(void)
{
    return (shared_data_t *)SHARED_BRAM_BASE;
}

static inline void shared_memory_barrier(void)
{
    __asm__ volatile("dmb sy" ::: "memory");
}

#endif

