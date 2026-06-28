#include <stdint.h>

#include "monte_carlo.h"

static uint32_t xorshift32(uint32_t *state)
{
    uint32_t x = *state;

    x ^= x << 13u;
    x ^= x >> 17u;
    x ^= x << 5u;

    *state = x;
    return x;
}

uint32_t monte_carlo_count(uint32_t samples, uint32_t seed)
{
    uint32_t inside = 0u;
    uint32_t state = seed;

    for (uint32_t i = 0u; i < samples; ++i) {
        const uint32_t x = xorshift32(&state) >> 16u;
        const uint32_t y = xorshift32(&state) >> 16u;
        const uint32_t radius2 = (x * x) + (y * y);

        if (radius2 <= MONTE_CARLO_UNIT_RADIUS2) {
            ++inside;
        }
    }

    return inside;
}
