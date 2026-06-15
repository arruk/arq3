#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

load_cross_config

required_headers=(
    usr/include/stdio.h
    usr/include/X11/Xlib.h
    usr/include/alsa/asoundlib.h
)

missing=()
for path in "${required_headers[@]}"; do
    if [[ ! -e "$SYSROOT/$path" ]]; then
        missing+=("$path")
    fi
done

find_library() {
    local pattern=$1
    find "$SYSROOT/lib" "$SYSROOT/usr/lib" \
        -name "$pattern" -print -quit 2>/dev/null
}

for library in libX11.so libasound.so libc.so crt1.o; do
    if [[ -z "$(find_library "$library")" ]]; then
        missing+=("$library")
    fi
done

if (( ${#missing[@]} > 0 )); then
    printf 'Sysroot incompleto. Itens ausentes:\n' >&2
    printf '  %s\n' "${missing[@]}" >&2
    cat >&2 <<'EOF'

A imagem runtime pode nao conter headers e links de desenvolvimento.
Nesse caso, instale/use o SDK Yocto correspondente ao BSP LXDE e configure
YOCTO_SDK_ENV em config/cross.env. Copiar apenas bibliotecas runtime nao e
suficiente para compilar SDL2 com X11 e ALSA.
EOF
    exit 1
fi

printf 'Sysroot validado: %s\n' "$SYSROOT"
