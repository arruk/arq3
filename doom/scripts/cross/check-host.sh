#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

load_cross_config

required=(
    autoreconf
    file
    git
    make
    pkg-config
    scp
    ssh
    tar
)

if ! require_commands "${required[@]}"; then
    cat >&2 <<'EOF'

Em Debian/Ubuntu:
  sudo apt install \
    autoconf automake libtool pkg-config make git file openssh-client \
    gcc-arm-linux-gnueabihf
EOF
    exit 1
fi

if [[ -n "$YOCTO_SDK_ENV" ]]; then
    printf 'SDK Yocto: %s\n' "$YOCTO_SDK_ENV"
    load_toolchain
else
    compiler="${CROSS_PREFIX}gcc"
    if ! command -v "$compiler" >/dev/null 2>&1; then
        printf 'Cross-compiler ausente: %s\n' "$compiler" >&2
        printf 'Em Debian/Ubuntu: sudo apt install gcc-arm-linux-gnueabihf\n' >&2
        exit 1
    fi
    load_toolchain
fi

printf 'CC: %s\n' "$CC"
printf 'Target: %s\n' "$TARGET_TRIPLE"
printf 'Sysroot: %s\n' "$SYSROOT"

if [[ ! -d "$SYSROOT" ]]; then
    printf 'Sysroot ainda nao existe. Execute scripts/cross/sync-sysroot.sh.\n'
fi
