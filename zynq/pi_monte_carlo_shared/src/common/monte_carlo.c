#include "monte_carlo.h"

static u32 xorshift32(u32 *state)
{
    u32 value = *state;

    value ^= value << 13;
    value ^= value >> 17;
    value ^= value << 5;
    *state = value;
    return value;
}

u32 monte_carlo_count(u32 samples, u32 seed)
{
    const u64 radius_squared = 65535ULL * 65535ULL;
    u32 state = seed;
    u32 inside = 0U;
    u32 i;

    for (i = 0U; i < samples; ++i) {
        u32 x = xorshift32(&state) & 0xFFFFU;
        u32 y = xorshift32(&state) & 0xFFFFU;
        u64 distance_squared = (u64)x * x + (u64)y * y;

        if (distance_squared <= radius_squared) {
            ++inside;
        }
    }

    return inside;
}

