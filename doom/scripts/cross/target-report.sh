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

require_commands ssh

ssh "$target" 'sh -s' <<'EOF'
set -eu

echo '=== Sistema ==='
uname -a
echo

echo '=== Arquitetura ==='
if command -v file >/dev/null 2>&1; then
    file /bin/sh
else
    echo "uname -m: $(uname -m)"
fi
echo

echo '=== glibc ==='
if command -v ldd >/dev/null 2>&1; then
    ldd --version 2>&1 | head -n 2 || true
fi
echo

echo '=== Video e audio ==='
cat /proc/fb 2>/dev/null || true
ls -l /dev/fb* 2>/dev/null || true
aplay -l 2>/dev/null || true
echo "DISPLAY=${DISPLAY-}"
echo

echo '=== Desenvolvimento ==='
for path in \
    /usr/include/stdio.h \
    /usr/include/X11/Xlib.h \
    /usr/include/alsa/asoundlib.h
do
    if [ -e "$path" ]; then
        echo "OK      $path"
    else
        echo "AUSENTE $path"
    fi
done

for library in libX11.so libasound.so libc.so crt1.o; do
    result=$(
        find /lib /usr/lib \
            -name "$library" \
            2>/dev/null |
            head -n 1
    )
    if [ -n "$result" ]; then
        echo "OK      $result"
    else
        echo "AUSENTE $library"
    fi
done

echo
echo '=== pkg-config ==='
if command -v pkg-config >/dev/null 2>&1; then
    pkg-config --modversion x11 2>/dev/null || true
    pkg-config --modversion alsa 2>/dev/null || true
    pkg-config --modversion sdl2 2>/dev/null || true
    pkg-config --modversion SDL2_mixer 2>/dev/null || true
else
    echo 'pkg-config ausente'
fi
EOF
