#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

readonly ROOT_DIR="$(cross_root_dir)"
readonly PACKAGE_FILE="$ROOT_DIR/dist/chocolate-doom-de10.tar.gz"

if [[ $# -lt 1 || $# -gt 2 ]]; then
    cat >&2 <<'EOF'
Uso:
  deploy-usb.sh <diretorio-montado-do-pendrive> [doom1.wad]
EOF
    exit 2
fi

mount_dir=$(realpath -m -- "$1")
wad=${2:-}
wad_name=doom1.wad
destination="$mount_dir/$(basename -- "$PACKAGE_FILE")"

if [[ ! -d "$mount_dir" ]]; then
    printf 'Diretorio nao encontrado: %s\n' "$mount_dir" >&2
    exit 1
fi

if [[ ! -f "$PACKAGE_FILE" ]]; then
    printf 'Pacote ausente. Execute scripts/cross/build.sh primeiro.\n' >&2
    exit 1
fi

if [[ -n "$wad" ]]; then
    if [[ ! -f "$wad" ]]; then
        printf 'WAD nao encontrado: %s\n' "$wad" >&2
        exit 1
    fi
    wad_name=$(basename -- "$wad")
fi

cp -- "$PACKAGE_FILE" "$destination"

if [[ -n "$wad" ]]; then
    cp -- "$wad" "$mount_dir/"
fi

sync
printf 'Copiado para %s\n' "$destination"
cat <<EOF
Na placa:
  mkdir -p /home/root
  tar -C /home/root -xzf /caminho/do/pendrive/chocolate-doom-de10.tar.gz
  cd /home/root/chocolate-doom-de10
  ./run-chocolate-doom.sh -iwad /caminho/do/pendrive/$wad_name
EOF
