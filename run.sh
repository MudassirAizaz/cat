#!/usr/bin/env bash
# Resolve the checkout rather than relying on the caller's working directory.
set -euo pipefail

launcher=$(readlink -f -- "${BASH_SOURCE[0]}")
project_dir=$(dirname -- "$launcher")

# Select this checkout even when the caller normally uses another Quickshell config.
unset QS_CONFIG_PATH QS_CONFIG_NAME QS_MANIFEST

if [[ "${1:-}" == ipc ]]; then
    shift
    exec quickshell ipc -p "$project_dir" "$@"
fi

exec quickshell -p "$project_dir" "$@"
