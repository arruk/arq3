#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<'EOF'
Uso:
  ./setup.sh <imagem.zip|imagem.img|URL> [dispositivo]

Exemplos:
  ./setup.sh ~/Downloads/DE10_Standard_LXDE.zip
  ./setup.sh ~/Downloads/DE10_Standard_LXDE.zip /dev/sdb

Sem o dispositivo, o script prepara a imagem e mostra os discos disponíveis.
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
    usage
    exit 2
fi

input=$1
device=${2:-}

"$ROOT_DIR/scripts/check-host.sh"
image=$("$ROOT_DIR/scripts/prepare-image.sh" "$input" --print-path-only)

printf '\nImagem preparada: %s\n\n' "$image"

if [[ -z "$device" ]]; then
    "$ROOT_DIR/scripts/list-disks.sh"
    cat <<EOF

Execute a gravação depois de identificar o microSD:
  "$ROOT_DIR/scripts/flash-sd.sh" "$image" /dev/sdX
EOF
    exit 0
fi

"$ROOT_DIR/scripts/flash-sd.sh" "$image" "$device"
"$ROOT_DIR/scripts/board-checklist.sh"
