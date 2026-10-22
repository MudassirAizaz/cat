#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
    suspend|hibernate|reboot|poweroff)
        exec systemctl "$1"
        ;;
    logout)
        if command -v hyprshutdown >/dev/null 2>&1; then
            exec hyprshutdown
        fi
        # This desktop uses Hyprland's Lua dispatchers; also support legacy configs.
        if hyprctl dispatch 'hl.dsp.exit()'; then
            exit 0
        fi
        exec hyprctl dispatch exit
        ;;
    *)
        printf 'Unknown session action: %s\n' "${1:-}" >&2
        exit 2
        ;;
esac
