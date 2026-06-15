#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF'
Checklist da DE10-Standard
==========================

Com a placa DESLIGADA, configure SW10 para MSEL[4:0] = 01010:

  SW10.1 (MSEL0): ON
  SW10.2 (MSEL1): OFF
  SW10.3 (MSEL2): ON
  SW10.4 (MSEL3): OFF
  SW10.5 (MSEL4): ON
  SW10.6:         indiferente

Conexões:

  [ ] microSD gravado inserido
  [ ] monitor conectado à saída VGA
  [ ] teclado e mouse conectados ao USB Host
  [ ] UART J4 conectada ao PC por USB Mini-B
  [ ] LINE OUT conectada quando for usar áudio

Depois, ligue a placa. O LXDE deve aparecer no VGA.

Console UART:

  ./scripts/serial-console.sh

Parâmetros: 115200 8N1, sem controle de fluxo.
Login: root, sem senha.
EOF
