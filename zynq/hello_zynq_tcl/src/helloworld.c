#include "platform.h"
#include "xil_printf.h"

int main(void)
{
    init_platform();

    xil_printf("Hello, World!\r\n");
    xil_printf("Executando somente no Cortex-A9 core 0.\r\n");

    cleanup_platform();
    return 0;
}

