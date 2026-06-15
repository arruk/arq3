#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

load_cross_config
SYSROOT=${SYSROOT:-$LOCAL_SYSROOT}

if [[ $# -ne 1 ]]; then
    cat >&2 <<'EOF'
Uso:
  sync-sysroot.sh <rootfs-local-montado|sysroot.tar.gz>

Exemplos:
  sync-sysroot.sh /media/$USER/rootfs
  sync-sysroot.sh /media/$USER/PENDRIVE/de10-sysroot.tar.gz

O diretorio ou arquivo deve conter lib, usr/include e usr/lib do Linux ARM.
EOF
    exit 2
fi

require_commands realpath tar
source_path=$(realpath -m -- "$1")

if [[ ! -e "$source_path" ]]; then
    printf 'Rootfs ou arquivo local nao encontrado: %s\n' "$source_path" >&2
    exit 1
fi

if [[ "$source_path" == "$(realpath -m -- "$SYSROOT")" ]]; then
    printf 'A origem e o destino do sysroot nao podem ser iguais.\n' >&2
    exit 1
fi

sysroot_parent=$(dirname -- "$SYSROOT")
sysroot_temp="$sysroot_parent/.sysroot.tmp.$$"
trap 'rm -rf -- "$sysroot_temp"' EXIT

mkdir -p -- "$sysroot_temp"

if [[ -d "$source_path" ]]; then
    paths=()
    for path in \
        lib \
        usr/lib \
        usr/include \
        usr/local/lib \
        usr/local/include
    do
        if [[ -e "$source_path/$path" ]]; then
            paths+=("$path")
        fi
    done

    if (( ${#paths[@]} == 0 )); then
        printf 'Nenhum diretorio de sysroot encontrado em %s.\n' \
            "$source_path" >&2
        exit 1
    fi

    printf 'Importando sysroot do rootfs local %s\n' "$source_path"
    tar -C "$source_path" -cf - "${paths[@]}" |
        tar -C "$sysroot_temp" --no-same-owner -xf -
elif [[ -f "$source_path" ]]; then
    if ! tar -tf "$source_path" >/dev/null; then
        printf 'Arquivo de sysroot invalido: %s\n' "$source_path" >&2
        exit 1
    fi

    while IFS= read -r archive_path; do
        normalized_path=${archive_path#./}
        if [[ "$archive_path" == /* ||
              "$normalized_path" == .. ||
              "$normalized_path" == ../* ||
              "$normalized_path" == */../* ||
              "$normalized_path" == */.. ]]; then
            printf 'Caminho inseguro no arquivo: %s\n' "$archive_path" >&2
            exit 1
        fi
    done < <(tar -tf "$source_path")

    printf 'Importando sysroot do arquivo %s\n' "$source_path"
    tar -C "$sysroot_temp" --no-same-owner -xf "$source_path"
else
    printf 'Origem nao suportada: %s\n' "$source_path" >&2
    exit 1
fi

"$SCRIPT_DIR/validate-sysroot.sh" "$sysroot_temp"

rm -rf -- "$SYSROOT"
mv -- "$sysroot_temp" "$SYSROOT"
trap - EXIT
printf 'Sysroot local preparado em %s\n' "$SYSROOT"
