#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Uso:
  serial-console.sh [dispositivo]

Exemplos:
  serial-console.sh
  serial-console.sh /dev/ttyUSB0
EOF
}

if [[ $# -gt 1 ]]; then
    usage
    exit 2
fi

if [[ $# -eq 1 ]]; then
    device=$1
else
    shopt -s nullglob
    candidates=(/dev/ttyUSB* /dev/ttyACM*)
    shopt -u nullglob

    if (( ${#candidates[@]} == 0 )); then
        printf 'Nenhuma porta /dev/ttyUSB* ou /dev/ttyACM* encontrada.\n' >&2
        exit 1
    fi

    if (( ${#candidates[@]} > 1 )); then
        printf 'Mais de uma porta serial encontrada:\n' >&2
        printf '  %s\n' "${candidates[@]}" >&2
        printf 'Informe a porta explicitamente.\n' >&2
        exit 1
    fi

    device=${candidates[0]}
fi

if [[ ! -c "$device" ]]; then
    printf 'Porta serial inválida: %s\n' "$device" >&2
    exit 1
fi

printf 'Abrindo %s em 115200 8N1, sem controle de fluxo.\n' "$device"

if command -v picocom >/dev/null 2>&1; then
    exec picocom \
        --baud 115200 \
        --databits 8 \
        --parity none \
        --stopbits 1 \
        --flow none \
        "$device"
fi

if command -v minicom >/dev/null 2>&1; then
    config_home=$(mktemp -d)
    trap 'rm -rf -- "$config_home"' EXIT

    cat > "$config_home/.minirc.de10-standard" <<EOF
pu port             $device
pu baudrate         115200
pu bits             8
pu parity           N
pu stopbits         1
pu rtscts           No
pu xonxoff          No
EOF

    HOME="$config_home" minicom --8bit --ansi --baudrate 115200 \
        --device "$device" de10-standard
    exit $?
fi

printf 'Instale picocom ou minicom para acessar o console serial.\n' >&2
exit 1
