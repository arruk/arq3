#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

readonly ROOT_DIR="$(cross_root_dir)"
readonly PACKAGE_DIR="$ROOT_DIR/dist/chocolate-doom-de10"

load_cross_config
require_target_host
require_commands scp ssh tar

wad=${1:-}
wad_name=doom1.wad

if [[ ! -x "$PACKAGE_DIR/run-chocolate-doom.sh" ]]; then
    printf 'Pacote ausente. Execute scripts/cross/build.sh primeiro.\n' >&2
    exit 1
fi

remote_dir=$(printf '%q' "$TARGET_DIR")

printf 'Enviando pacote para %s:%s\n' "$TARGET_HOST" "$TARGET_DIR"
tar -C "$PACKAGE_DIR" -cf - . |
    ssh "$TARGET_HOST" "mkdir -p $remote_dir && tar -C $remote_dir -xf -"

if [[ -n "$wad" ]]; then
    if [[ ! -f "$wad" ]]; then
        printf 'WAD nao encontrado: %s\n' "$wad" >&2
        exit 1
    fi
    wad_name=$(basename -- "$wad")
    scp -- "$wad" "$TARGET_HOST:$TARGET_DIR/"
fi

ssh "$TARGET_HOST" "chmod +x $remote_dir/run-chocolate-doom.sh $remote_dir/run-chocolate-setup.sh"

cat <<EOF

Deploy concluido. Na placa:
  cd "$TARGET_DIR"
  ./run-chocolate-doom.sh -iwad "$wad_name"
EOF
