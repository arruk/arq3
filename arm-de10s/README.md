# ARM bare-metal na DE10-Standard

Este diretório contém dois exemplos para o HPS ARM Cortex-A9 dual-core da
DE10-Standard, sem depender de uma instalação local do Quartus.

- `hello_uart`: usa apenas o core 0 e imprime `hello, world!` na UART0 do HPS.
- `pi_monte_carlo`: usa os dois cores Cortex-A9. O core 0 copia a imagem do
  core 1 para a SDRAM, libera o CPU1 pelo Reset Manager/System Manager do HPS e
  os dois cores acumulam o cálculo de pi por Monte Carlo usando uma estrutura em
  memória compartilhada na OCRAM do HPS.

## Pré-requisitos

Use um toolchain ARM bare-metal compatível com Cortex-A9:

```sh
make CROSS_COMPILE=arm-none-eabi-
```

Se estiver usando o toolchain do SoC EDS antigo, ajuste o prefixo:

```sh
make CROSS_COMPILE=arm-altera-eabi-
```

Para sobrescrever baud rate ou clock de entrada da UART:

```sh
make EXTRA_CFLAGS="-DHPS_UART_CLK_HZ=100000000u -DHPS_UART_BAUD=115200u"
```

O projeto assume que a placa já passou pelo boot normal da DE10-Standard, de
forma que a SDRAM e a UART0 do HPS estejam com clock e pin mux configurados pelo
preloader/U-Boot ou por um fluxo equivalente.

## Endereços usados

- UART0 HPS: `0xFFC02000`
- Reset Manager HPS: `0xFFD05000`
- System Manager HPS: `0xFFD08000`
- OCRAM compartilhada: `0xFFFF0000`
- `hello_uart` e `pi_monte_carlo/core0`: `0x00100000`
- `pi_monte_carlo/core1`: `0x00200000`

Esses endereços ficam no mapa de memória padrão do Cyclone V HPS usado pela
DE10-Standard.

## Build

```sh
make
```

Artefatos gerados:

- `build/hello_uart/hello_uart.elf`
- `build/hello_uart/hello_uart.bin`
- `build/pi_monte_carlo/core0.elf`
- `build/pi_monte_carlo/core0.bin`
- `build/pi_monte_carlo/core1.elf`
- `build/pi_monte_carlo/core1.bin`

Para limpar:

```sh
make clean
```

## Execução

### Via JTAG/OpenOCD sem remover o SD card

Este fluxo carrega o programa na RAM do HPS via JTAG. Ele pode ser iniciado com
o Linux ainda rodando, mas o comando do GDB substitui a execução do Linux pelo
programa bare-metal. Rode `sync` no Linux da placa antes do teste e reinicie a
placa para voltar ao Linux depois.

Abra a UART em um terminal:

```sh
sudo picocom -b 115200 /dev/ttyUSB0
```

Para sair do `picocom`:

```text
Ctrl-a Ctrl-x
```

Em outro terminal, inicie o OpenOCD:

```sh
sudo openocd -s /usr/local/share/openocd/scripts \
  -f interface/altera-usb-blaster2.cfg \
  -c "usb_blaster firmware /var/local/intelFPGA_lite/23.1std/quartus/linux64/blaster_6810.hex" \
  -f openocd/de10_standard_hps.cfg
```

O arquivo [openocd/de10_standard_hps.cfg](openocd/de10_standard_hps.cfg)
considera a ordem JTAG vista na DE10-Standard usada aqui:

```text
02D020DD   5CSEBA6...
4BA00477   SOCVHPS
```

Para testar a conexão sem parar o Linux:

```sh
sudo openocd -s /usr/local/share/openocd/scripts \
  -f interface/altera-usb-blaster2.cfg \
  -c "usb_blaster firmware /var/local/intelFPGA_lite/23.1std/quartus/linux64/blaster_6810.hex" \
  -f openocd/de10_standard_hps.cfg \
  -c "init; scan_chain; targets; shutdown"
```

Carregue e execute o `hello_uart` com GDB:

```sh
gdb-multiarch build/hello_uart/hello_uart.elf \
  -ex "target remote localhost:3333" \
  -ex "monitor hps_baremetal_prepare" \
  -ex "load" \
  -ex "set \$pc = 0x00100000" \
  -ex "continue"
```

Carregue e execute o Monte Carlo dual-core:

```sh
gdb-multiarch build/pi_monte_carlo/core0.elf \
  -ex "target remote localhost:3333" \
  -ex "monitor hps_baremetal_prepare" \
  -ex "load" \
  -ex "set \$pc = 0x00100000" \
  -ex "continue"
```

Use `monitor hps_baremetal_prepare`, não apenas `monitor halt`: o Linux deixa a
MMU ligada, e saltar diretamente para `0x00100000` com a MMU ativa causa um
page fault no kernel.

### Hello world

Carregue `build/hello_uart/hello_uart.elf` no endereço de link `0x00100000` e
inicie o core 0 nesse endereço. A saída esperada na UART0 é:

```text
hello, world!
```

### Pi Monte Carlo dual-core

Carregue e execute apenas `build/pi_monte_carlo/core0.elf` no core 0. A imagem
binária do core 1 já vai embutida dentro do ELF do core 0; o core 0 faz a cópia
para `0x00200000` e libera o CPU1 automaticamente.

Execute esse exemplo com o CPU1 parado/em reset. Se o seu monitor/debugger já
tiver liberado o segundo core antes, reinicie a placa ou segure o CPU1 em reset
antes de entrar no `core0`.

A saída na UART0 mostra as amostras por core, total de pontos dentro do círculo
e pi estimado em ponto fixo com seis casas decimais.

## Ajustes úteis

O número total de amostras fica em
`pi_monte_carlo/shared_data.h`:

```c
#define PI_TOTAL_SAMPLES 2000000u
```

Se o seu fluxo de carga usar outro mapa de SDRAM, altere os endereços em:

- `linker/hello.ld`
- `linker/core0.ld`
- `linker/core1.ld`
- `common/socfpga.h`
