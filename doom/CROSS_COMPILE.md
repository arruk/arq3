# Cross-compilação para a DE10-Standard

Este fluxo compila no host x86_64 e executa no ARM Cortex-A9 da
DE10-Standard:

```text
Host x86_64
  -> cross-compiler ARM hard-float
  -> sysroot do Linux LXDE Terasic
  -> SDL2 + SDL2_mixer + Chocolate Doom
  -> scp ou pendrive
  -> HPS ARMv7 da DE10-Standard
```

O pacote gerado contém SDL2 e SDL2_mixer privadas. X11, ALSA, `glibc` e
demais componentes básicos continuam vindo do BSP LXDE da placa.

## Versões fixadas

| Componente | Versão |
|---|---|
| Chocolate Doom | `3.1.1` |
| SDL | `2.0.14` |
| SDL_mixer | `2.0.4` |

Os scripts também conferem os commits correspondentes às tags oficiais.
SDL2_net, FluidSynth, libpng e libsamplerate ficam desabilitados para reduzir
as dependências. SDL_mixer mantém efeitos sonoros, WAVE e MIDI Timidity.

## 1. Preparar o host

Em Debian/Ubuntu:

```bash
sudo apt install \
  autoconf automake libtool pkg-config make git file openssh-client \
  gcc-arm-linux-gnueabihf
```

Confira:

```bash
./scripts/cross/check-host.sh
```

Para maior compatibilidade com o BSP antigo, prefira o SDK Yocto/Terasic que
gerou a imagem LXDE. A toolchain Debian é uma alternativa, mas ainda deve
usar o sysroot exato da placa.

## 2. Configurar a placa

Conecte a DE10-Standard por Ethernet e descubra o endereço:

```bash
ip addr show eth0
```

No host:

```bash
cp config/cross.env.example config/cross.env
```

Edite:

```bash
TARGET_HOST=root@192.168.1.50
TARGET_DIR=/home/root/chocolate-doom
```

`config/cross.env` não é versionado.

Teste o SSH:

```bash
ssh root@192.168.1.50 uname -a
```

## 3. Inspecionar o BSP

```bash
./scripts/cross/target-report.sh
```

O relatório verifica arquitetura, `glibc`, framebuffer, ALSA e a presença de:

```text
/usr/include/stdio.h
/usr/include/X11/Xlib.h
/usr/include/alsa/asoundlib.h
libX11.so
libasound.so
libc.so
crt1.o
```

## 4. Obter o sysroot

Tente sincronizar o sistema da própria placa:

```bash
./scripts/cross/sync-sysroot.sh
```

O resultado fica em `build/sysroot` e é validado automaticamente.

Uma imagem runtime frequentemente possui bibliotecas, mas não headers e
links de desenvolvimento. Se a validação falhar, será necessário instalar o
SDK Yocto correspondente ao BSP. Configure então:

```bash
YOCTO_SDK_ENV=/opt/poky/.../environment-setup-...
```

Quando `YOCTO_SDK_ENV` está definido, o script usa automaticamente variáveis
como `CC`, `TARGET_PREFIX` e `SDKTARGETSYSROOT` fornecidas pelo SDK.

Não use headers de Debian ARM com a `glibc` do Yocto: isso pode produzir um
binário que compila no host e falha ao iniciar na placa.

## 5. Compilar

O comando completo é:

```bash
./cross-build.sh
```

Ele executa:

```text
scripts/cross/check-host.sh
scripts/cross/fetch-sources.sh
scripts/cross/build.sh
```

Os resultados são:

```text
dist/chocolate-doom-de10/
dist/chocolate-doom-de10.tar.gz
```

Para descartar apenas os artefatos de compilação e preservar fontes/sysroot:

```bash
./scripts/cross/clean.sh
```

Estrutura do pacote:

```text
chocolate-doom-de10/
  bin/chocolate-doom
  bin/chocolate-setup
  lib/libSDL2-2.0.so.0
  lib/libSDL2_mixer-2.0.so.0
  run-chocolate-doom.sh
  run-chocolate-setup.sh
```

O launcher configura:

```text
DISPLAY=:0.0
SDL_VIDEODRIVER=x11
SDL_AUDIODRIVER=alsa
LD_LIBRARY_PATH=<pacote>/lib
```

## 6. Enviar por Ethernet

Use um IWAD obtido legalmente, como `doom1.wad`, ou Freedoom:

```bash
./scripts/cross/deploy-scp.sh /caminho/doom1.wad
```

Sem copiar WAD:

```bash
./scripts/cross/deploy-scp.sh
```

Na placa:

```bash
cd /home/root/chocolate-doom
./run-chocolate-setup.sh
./run-chocolate-doom.sh -iwad doom1.wad
```

## 7. Enviar por pendrive

No host, com o pendrive montado:

```bash
./scripts/cross/deploy-usb.sh /media/$USER/PENDRIVE /caminho/doom1.wad
```

Na placa:

```bash
mkdir -p /home/root/chocolate-doom
cp -a /caminho/do/usb/chocolate-doom-de10/. /home/root/chocolate-doom/
cd /home/root/chocolate-doom
./run-chocolate-doom.sh -iwad doom1.wad
```

## Diagnóstico na placa

```bash
cd /home/root/chocolate-doom
file bin/chocolate-doom
LD_LIBRARY_PATH="$PWD/lib" ldd bin/chocolate-doom
echo "$DISPLAY"
cat /proc/fb
aplay -l
```

O `file` deve indicar `ELF 32-bit`, `ARM` e `EABI5`. Se `ldd` reportar uma
biblioteca ausente, ela deve vir do mesmo BSP/SDK usado no sysroot.

O IWAD não é baixado ou incluído pelos scripts.
