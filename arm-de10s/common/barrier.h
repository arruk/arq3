#ifndef BARRIER_H
#define BARRIER_H

static inline void cpu_dmb(void)
{
    __asm__ volatile("dmb sy" ::: "memory");
}

static inline void cpu_dsb(void)
{
    __asm__ volatile("dsb sy" ::: "memory");
}

static inline void cpu_isb(void)
{
    __asm__ volatile("isb sy" ::: "memory");
}

static inline void cpu_wfe(void)
{
    __asm__ volatile("wfe" ::: "memory");
}

static inline void cpu_sev(void)
{
    __asm__ volatile("sev" ::: "memory");
}

#endif
