#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

readonly ROOT_DIR="$(cross_root_dir)"
readonly PACKAGE_DIR="$ROOT_DIR/dist/chocolate-doom-de10"

if [[ $# -lt 1 || $# -gt 2 ]]; then
    cat >&2 <<'EOF'
Uso:
  deploy-usb.sh <diretorio-montado-do-pendrive> [doom1.wad]
EOF
    exit 2
fi

mount_dir=$(realpath -- "$1")
wad=${2:-}
destination="$mount_dir/chocolate-doom-de10"

if [[ ! -d "$mount_dir" ]]; then
    printf 'Diretorio nao encontrado: %s\n' "$mount_dir" >&2
    exit 1
fi

if [[ ! -x "$PACKAGE_DIR/run-chocolate-doom.sh" ]]; then
    printf 'Pacote ausente. Execute scripts/cross/build.sh primeiro.\n' >&2
    exit 1
fi

mkdir -p -- "$destination"
cp -a -- "$PACKAGE_DIR/." "$destination/"

if [[ -n "$wad" ]]; then
    cp -- "$wad" "$destination/"
fi

sync
printf 'Copiado para %s\n' "$destination"
printf 'Na placa, copie esse diretorio para /home/root antes de executar.\n'
