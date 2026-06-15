# DE10-Standard: Linux LXDE no microSD

Este diretório contém um workflow para preparar o Linux LXDE da Terasic,
gravar o microSD e acessar o console serial da DE10-Standard.

## Requisitos no computador

O fluxo foi escrito para Linux e usa:

- `bash`
- `curl`
- `unzip`
- `lsblk` e `findmnt` (`util-linux`)
- `dd`, `cmp` e `sha256sum` (`coreutils`)
- `sudo`
- `picocom` ou `minicom` para o console serial

Confira o ambiente:

```bash
./scripts/check-host.sh
```

Em Debian/Ubuntu, os pacotes normalmente podem ser instalados com:

```bash
sudo apt install curl unzip util-linux coreutils picocom
```

## 1. Obter e preparar a imagem

Baixe **Linux LXDE Desktop (Kernel 4.5)** na página oficial:

<https://www.terasic.com.tw/cgi-bin/page/archive.pl?CategoryNo=167&Language=English&No=1081&PartNo=4>

O download da imagem LXDE usa um formulário com sessão no site da Terasic.
Depois do download, prepare a imagem:

```bash
./scripts/prepare-image.sh ~/Downloads/DE10_Standard_LXDE.zip
```

O script também aceita uma imagem `.img` já extraída ou uma URL:

```bash
./scripts/prepare-image.sh /caminho/de10_standard_lxde.img
./scripts/prepare-image.sh 'https://servidor/exemplo.zip'
```

O resultado fica em `build/images/`. O script imprime o caminho exato e o
SHA-256 da imagem.

## 2. Identificar o microSD

Insira o microSD e execute:

```bash
./scripts/list-disks.sh
```

Confirme o dispositivo usando tamanho, modelo e transporte. Use o disco
inteiro, por exemplo `/dev/sdb`, e não uma partição como `/dev/sdb1`.

## 3. Gravar e verificar

```bash
./scripts/flash-sd.sh build/images/de10_standard_lxde.img /dev/sdX
```

O script:

1. recusa partições e o disco que contém `/`;
2. exige confirmação digitada;
3. desmonta as partições do cartão;
4. grava com `dd`;
5. sincroniza os dados;
6. compara a imagem com o início do cartão.

Todos os dados do dispositivo escolhido serão apagados.

Também é possível executar o assistente completo:

```bash
./setup.sh ~/Downloads/DE10_Standard_LXDE.zip /dev/sdX
```

## 4. Configurar a placa

Faça isto com a DE10-Standard desligada.

Para o BSP LXDE, configure `MSEL[4:0] = 01010` no `SW10`:

| Chave | Posição |
|---|---|
| `SW10.1` (`MSEL0`) | `ON` |
| `SW10.2` (`MSEL1`) | `OFF` |
| `SW10.3` (`MSEL2`) | `ON` |
| `SW10.4` (`MSEL3`) | `OFF` |
| `SW10.5` (`MSEL4`) | `ON` |
| `SW10.6` | indiferente |

Depois:

1. insira o microSD;
2. conecte o monitor VGA;
3. conecte teclado e mouse às portas USB Host;
4. conecte a saída de áudio `LINE OUT` quando necessário;
5. conecte a porta UART `J4` ao computador por USB Mini-B;
6. ligue a placa.

O HPS carrega o Linux e configura na FPGA o projeto de framebuffer que gera
o sinal VGA. A UART não transporta a imagem; ela fornece apenas o console.

Mostre novamente o checklist:

```bash
./scripts/board-checklist.sh
```

## 5. Console serial

Após ligar a placa:

```bash
./scripts/serial-console.sh
```

Também é possível informar a porta:

```bash
./scripts/serial-console.sh /dev/ttyUSB0
```

Parâmetros: `115200 8N1`, sem controle de fluxo. Login:

```text
usuário: root
senha: nenhuma
```

Para sair do `picocom`, use `Ctrl-A`, depois `Ctrl-X`. No `minicom`, use
`Ctrl-A`, depois `X`.

## Diagnóstico após o boot

No console da placa:

```bash
uname -a
cat /proc/fb
ls -l /dev/fb*
fbset
aplay -l
echo "$DISPLAY"
```

Para executar aplicações gráficas a partir da UART:

```bash
export DISPLAY=:0.0
```

## Cross-compilar Chocolate Doom

O workflow completo de compilação está em
[CROSS_COMPILE.md](CROSS_COMPILE.md). Resumo:

```text
Host x86_64
  -> toolchain/sysroot ARMv7 do BSP
  -> SDL 2.0.14 + SDL_mixer 2.0.4
  -> Chocolate Doom 3.1.1
  -> pacote com executável e bibliotecas SDL
  -> scp ou pendrive
  -> DE10-Standard
```

Com a placa ligada e conectada à rede:

```bash
cp config/cross.env.example config/cross.env
# Edite TARGET_HOST em config/cross.env.

./scripts/cross/target-report.sh
./scripts/cross/sync-sysroot.sh
./cross-build.sh
./scripts/cross/deploy-scp.sh /caminho/doom1.wad
```

O BSP runtime pode não possuir os headers X11 e ALSA. Se
`sync-sysroot.sh` reportar esses arquivos como ausentes, use o SDK
Yocto/Terasic correspondente e configure `YOCTO_SDK_ENV`; não misture
bibliotecas ARM de outra distribuição.

## Referências

- [Recursos da DE10-Standard](https://www.terasic.com.tw/cgi-bin/page/archive.pl?CategoryNo=167&Language=English&No=1081&PartNo=4)
- [Manual oficial da DE10-Standard](https://www.terasic.com.tw/cgi-bin/page/archive_download.pl?Language=English&No=1081&FID=551f9fbfa8ed07843cd51831db1b04dd)
- [Chocolate Doom](https://github.com/chocolate-doom/chocolate-doom)
- [SDL](https://github.com/libsdl-org/SDL)
- [SDL_mixer](https://github.com/libsdl-org/SDL_mixer)
