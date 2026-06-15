#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
readonly DOWNLOAD_DIR="$ROOT_DIR/build/downloads"
readonly IMAGE_DIR="$ROOT_DIR/build/images"

usage() {
    cat <<'EOF'
Uso:
  prepare-image.sh <arquivo.zip|arquivo.img|URL> [--print-path-only]

Prepara uma imagem de microSD em build/images e imprime seu SHA-256.
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
    usage
    exit 2
fi

input=$1
output_mode=${2:-}

if [[ -n "$output_mode" && "$output_mode" != "--print-path-only" ]]; then
    usage
    exit 2
fi

mkdir -p -- "$DOWNLOAD_DIR" "$IMAGE_DIR"

if [[ "$input" =~ ^https?:// ]]; then
    filename=${input%%\?*}
    filename=${filename##*/}
    [[ -n "$filename" ]] || filename=de10-standard-linux-download
    source_file="$DOWNLOAD_DIR/$filename"

    printf 'Baixando %s\n' "$input" >&2
    curl --fail --location --progress-bar --output "$source_file.part" "$input"
    mv -- "$source_file.part" "$source_file"
else
    source_file=$(realpath -- "$input")
fi

if [[ ! -f "$source_file" ]]; then
    printf 'Arquivo não encontrado: %s\n' "$source_file" >&2
    exit 1
fi

case "${source_file,,}" in
    *.img)
        destination="$IMAGE_DIR/$(basename -- "$source_file")"
        if [[ "$source_file" != "$destination" ]]; then
            cp --reflink=auto -- "$source_file" "$destination"
        fi
        ;;
    *.zip)
        mapfile -t image_entries < <(
            unzip -Z1 "$source_file" |
                sed -n '/\.img$/Ip'
        )

        if (( ${#image_entries[@]} != 1 )); then
            printf 'Esperava exatamente uma imagem .img no ZIP; encontrei %d:\n' \
                "${#image_entries[@]}" >&2
            printf '  %s\n' "${image_entries[@]:-nenhuma}" >&2
            exit 1
        fi

        entry=${image_entries[0]}
        destination="$IMAGE_DIR/$(basename -- "$entry")"
        printf 'Extraindo %s\n' "$entry" >&2
        unzip -p "$source_file" "$entry" > "$destination.part"
        mv -- "$destination.part" "$destination"
        ;;
    *)
        printf 'Formato não suportado: %s\n' "$source_file" >&2
        printf 'Use um arquivo .zip ou .img.\n' >&2
        exit 1
        ;;
esac

if [[ ! -s "$destination" ]]; then
    printf 'A imagem preparada está vazia: %s\n' "$destination" >&2
    exit 1
fi

if [[ "$output_mode" == "--print-path-only" ]]; then
    printf '%s\n' "$destination"
else
    printf 'Imagem: %s\n' "$destination"
    printf 'Tamanho: %s\n' "$(du -h -- "$destination" | cut -f1)"
    sha256sum -- "$destination"
fi
