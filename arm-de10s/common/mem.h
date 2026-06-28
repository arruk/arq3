#ifndef MEM_H
#define MEM_H

#include <stddef.h>

void mem_zero(void *dst, size_t len);
void mem_copy(void *dst, const void *src, size_t len);

#endif
