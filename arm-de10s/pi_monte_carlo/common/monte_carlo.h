#ifndef MONTE_CARLO_H
#define MONTE_CARLO_H

#include <stdint.h>

#define MONTE_CARLO_COORD_MAX 0xFFFFu
#define MONTE_CARLO_UNIT_RADIUS2 \
    (MONTE_CARLO_COORD_MAX * MONTE_CARLO_COORD_MAX)

uint32_t monte_carlo_count(uint32_t samples, uint32_t seed);

#endif
