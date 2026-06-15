#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

"$ROOT_DIR/scripts/cross/check-host.sh"
"$ROOT_DIR/scripts/cross/fetch-sources.sh"
CROSS_HOST_CHECKED=1 "$ROOT_DIR/scripts/cross/build.sh"
