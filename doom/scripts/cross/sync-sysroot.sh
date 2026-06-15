#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

load_cross_config
target=${1:-$TARGET_HOST}

if [[ -z "$target" ]]; then
    require_target_host
    target=$TARGET_HOST
fi

require_commands ssh tar
mkdir -p -- "$SYSROOT"

printf 'Sincronizando sysroot de %s para %s\n' "$target" "$SYSROOT"

ssh "$target" 'sh -s' <<'EOF' |
set -eu
set --
for path in \
    lib \
    usr/lib \
    usr/include \
    usr/local/lib \
    usr/local/include
do
    if [ -e "/$path" ]; then
        set -- "$@" "$path"
    fi
done

if [ "$#" -eq 0 ]; then
    echo 'Nenhum diretorio de sysroot encontrado.' >&2
    exit 1
fi

tar -C / -cf - "$@"
EOF
    tar -C "$SYSROOT" --no-same-owner -xf -

"$SCRIPT_DIR/validate-sysroot.sh"
