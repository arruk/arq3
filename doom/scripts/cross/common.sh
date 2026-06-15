#!/usr/bin/env bash

cross_root_dir() {
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd
}

load_cross_config() {
    local root_dir config_file

    root_dir=$(cross_root_dir)
    config_file="$root_dir/config/cross.env"

    if [[ -f "$config_file" ]]; then
        # shellcheck disable=SC1090
        source "$config_file"
    fi

    TARGET_TRIPLE=${TARGET_TRIPLE:-arm-linux-gnueabihf}
    CROSS_PREFIX=${CROSS_PREFIX:-${TARGET_TRIPLE}-}
    SYSROOT=${SYSROOT:-}
    LOCAL_SYSROOT="$root_dir/build/sysroot"
    YOCTO_SDK_ENV=${YOCTO_SDK_ENV:-}
    TARGET_CFLAGS=${TARGET_CFLAGS:--O2 -pipe -mcpu=cortex-a9 -mfpu=neon -mfloat-abi=hard}
    JOBS=${JOBS:-}

    export TARGET_TRIPLE CROSS_PREFIX SYSROOT LOCAL_SYSROOT
    export YOCTO_SDK_ENV TARGET_CFLAGS JOBS
}

require_commands() {
    local command_name
    local -a missing=()

    for command_name in "$@"; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            missing+=("$command_name")
        fi
    done

    if (( ${#missing[@]} > 0 )); then
        printf 'Comandos ausentes:\n' >&2
        printf '  %s\n' "${missing[@]}" >&2
        return 1
    fi
}

load_toolchain() {
    local compiler_sysroot

    if [[ -n "$YOCTO_SDK_ENV" ]]; then
        if [[ ! -f "$YOCTO_SDK_ENV" ]]; then
            printf 'YOCTO_SDK_ENV nao encontrado: %s\n' "$YOCTO_SDK_ENV" >&2
            return 1
        fi

        set +u
        # shellcheck disable=SC1090
        source "$YOCTO_SDK_ENV"
        set -u

        if [[ -n "${SDKTARGETSYSROOT:-}" ]]; then
            SYSROOT=$SDKTARGETSYSROOT
            export SYSROOT
        fi

        if [[ -n "${TARGET_PREFIX:-}" ]]; then
            TARGET_TRIPLE=${TARGET_PREFIX%-}
            CROSS_PREFIX=$TARGET_PREFIX
            export TARGET_TRIPLE CROSS_PREFIX
        fi
    else
        if [[ -z "$SYSROOT" ]]; then
            compiler_sysroot=$("${CROSS_PREFIX}gcc" -print-sysroot)
            if [[ -n "$compiler_sysroot" &&
                  "$compiler_sysroot" != "/" &&
                  -d "$compiler_sysroot" ]]; then
                SYSROOT=$compiler_sysroot
                printf 'Sysroot detectado pelo compilador: %s\n' "$SYSROOT"
            else
                SYSROOT=$LOCAL_SYSROOT
            fi
            export SYSROOT
        fi

        export CC="${CROSS_PREFIX}gcc --sysroot=$SYSROOT"
        export AR="${CROSS_PREFIX}ar"
        export AS="${CROSS_PREFIX}as"
        export LD="${CROSS_PREFIX}ld"
        export NM="${CROSS_PREFIX}nm"
        export OBJCOPY="${CROSS_PREFIX}objcopy"
        export OBJDUMP="${CROSS_PREFIX}objdump"
        export RANLIB="${CROSS_PREFIX}ranlib"
        export READELF="${CROSS_PREFIX}readelf"
        export STRIP="${CROSS_PREFIX}strip"
    fi

    : "${CC:?A toolchain nao definiu CC}"
    : "${AR:?A toolchain nao definiu AR}"
    : "${RANLIB:?A toolchain nao definiu RANLIB}"

    if [[ -z "${READELF:-}" ]]; then
        READELF="${CROSS_PREFIX}readelf"
        export READELF
    fi
}

parallel_jobs() {
    if [[ -n "$JOBS" ]]; then
        printf '%s\n' "$JOBS"
    elif command -v nproc >/dev/null 2>&1; then
        nproc
    else
        printf '2\n'
    fi
}
