#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

load_cross_config

if [[ $# -ne 1 ]]; then
    cat >&2 <<'EOF'
Uso:
  sync-sysroot.sh <rootfs-local-montado>

Exemplo:
  sync-sysroot.sh /media/$USER/rootfs

O diretorio deve ser a raiz do Linux ARM e conter usr/include e usr/lib.
EOF
    exit 2
fi

require_commands realpath tar
source_root=$(realpath -m -- "$1")

if [[ ! -d "$source_root" ]]; then
    printf 'Rootfs local nao encontrado: %s\n' "$source_root" >&2
    exit 1
fi

if [[ "$source_root" == "$(realpath -m -- "$SYSROOT")" ]]; then
    printf 'A origem e o destino do sysroot nao podem ser iguais.\n' >&2
    exit 1
fi

paths=()
for path in \
    lib \
    usr/lib \
    usr/include \
    usr/local/lib \
    usr/local/include
do
    if [[ -e "$source_root/$path" ]]; then
        paths+=("$path")
    fi
done

if (( ${#paths[@]} == 0 )); then
    printf 'Nenhum diretorio de sysroot encontrado em %s.\n' "$source_root" >&2
    exit 1
fi

sysroot_parent=$(dirname -- "$SYSROOT")
sysroot_temp="$sysroot_parent/.sysroot.tmp.$$"
trap 'rm -rf -- "$sysroot_temp"' EXIT

mkdir -p -- "$sysroot_temp"
printf 'Importando sysroot local de %s\n' "$source_root"
tar -C "$source_root" -cf - "${paths[@]}" |
    tar -C "$sysroot_temp" --no-same-owner -xf -

"$SCRIPT_DIR/validate-sysroot.sh" "$sysroot_temp"

rm -rf -- "$SYSROOT"
mv -- "$sysroot_temp" "$SYSROOT"
trap - EXIT
printf 'Sysroot local preparado em %s\n' "$SYSROOT"
