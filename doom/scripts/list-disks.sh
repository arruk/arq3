#!/usr/bin/env bash
set -euo pipefail

printf 'Discos detectados:\n\n'
lsblk --paths --nodeps \
    --output NAME,SIZE,RM,RO,TRAN,MODEL,SERIAL

cat <<'EOF'

Use somente o dispositivo do microSD inteiro, por exemplo /dev/sdb.
Não use uma partição como /dev/sdb1.

RM=1 normalmente indica mídia removível, mas alguns leitores USB reportam
RM=0. Confirme sempre tamanho, modelo e transporte antes de gravar.
EOF
