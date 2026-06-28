#include <stddef.h>
#include <stdint.h>

#include "barrier.h"
#include "mem.h"

void mem_zero(void *dst, size_t len)
{
    uint8_t *out = (uint8_t *)dst;

    while (len-- != 0u) {
        *out++ = 0u;
    }
}

void mem_copy(void *dst, const void *src, size_t len)
{
    uint8_t *out = (uint8_t *)dst;
    const uint8_t *in = (const uint8_t *)src;

    while (len-- != 0u) {
        *out++ = *in++;
    }

    cpu_dsb();
    cpu_isb();
}
