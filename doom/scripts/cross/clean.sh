#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

readonly ROOT_DIR="$(cross_root_dir)"

rm -rf -- "$ROOT_DIR/build/cross" "$ROOT_DIR/dist"
printf 'Artefatos de compilacao removidos.\n'
