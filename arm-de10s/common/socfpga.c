#include <stdint.h>

#include "barrier.h"
#include "mmio.h"
#include "socfpga.h"

void socfpga_start_cpu1(uint32_t entry_addr)
{
    mmio_write32(SOCFPGA_SYSMGR_CPU1STARTADDR, entry_addr);
    cpu_dsb();

    mmio_write32(SOCFPGA_RSTMGR_MPUMODRST,
                 mmio_read32(SOCFPGA_RSTMGR_MPUMODRST) &
                     ~SOCFPGA_RSTMGR_MPUMODRST_CPU1);
    cpu_dsb();
    cpu_sev();
}

void socfpga_park_current_cpu(void)
{
    for (;;) {
        cpu_wfe();
    }
}
