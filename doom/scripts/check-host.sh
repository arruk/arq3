#!/usr/bin/env bash
set -euo pipefail

required=(
    bash
    cmp
    curl
    dd
    findmnt
    lsblk
    numfmt
    realpath
    sha256sum
    stat
    sudo
    sync
    unzip
)

missing=()

for command_name in "${required[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        missing+=("$command_name")
    fi
done

if (( ${#missing[@]} > 0 )); then
    printf 'Dependências obrigatórias ausentes:\n' >&2
    printf '  %s\n' "${missing[@]}" >&2
    exit 1
fi

if command -v picocom >/dev/null 2>&1; then
    serial_tool=picocom
elif command -v minicom >/dev/null 2>&1; then
    serial_tool=minicom
else
    serial_tool='ausente (instale picocom ou minicom)'
fi

printf 'Dependências obrigatórias: OK\n'
printf 'Ferramenta serial: %s\n' "$serial_tool"
