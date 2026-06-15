#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

readonly ROOT_DIR="$(cross_root_dir)"
readonly SOURCE_DIR="$ROOT_DIR/build/sources"

require_commands git
mkdir -p -- "$SOURCE_DIR"

fetch_exact() {
    local name=$1
    local repository=$2
    local ref=$3
    local commit=$4
    local destination="$SOURCE_DIR/$name"

    if [[ ! -d "$destination/.git" ]]; then
        printf 'Clonando %s (%s)\n' "$name" "$ref"
        git clone --depth 1 --branch "$ref" "$repository" "$destination"
    fi

    actual=$(git -C "$destination" rev-parse HEAD)
    if [[ "$actual" != "$commit" ]]; then
        printf '%s esta em um commit inesperado.\n' "$destination" >&2
        printf 'Esperado: %s\nAtual:    %s\n' "$commit" "$actual" >&2
        exit 1
    fi
}

fetch_exact \
    chocolate-doom \
    https://github.com/chocolate-doom/chocolate-doom.git \
    chocolate-doom-3.1.1 \
    410d96855b5df5410ff591a90efeafa889119224

fetch_exact \
    SDL \
    https://github.com/libsdl-org/SDL.git \
    release-2.0.14 \
    4cd981609b50ed273d80c635c1ca4c1e5518fb21

fetch_exact \
    SDL_mixer \
    https://github.com/libsdl-org/SDL_mixer.git \
    release-2.0.4 \
    da75a58c19de9fedea62724a5f7770cbbe39adf9

printf 'Fontes verificadas em %s\n' "$SOURCE_DIR"
