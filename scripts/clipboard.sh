#!/usr/bin/env bash
set -euo pipefail

command -v cliphist >/dev/null || { echo 'Install cliphist to use clipboard history.' >&2; exit 1; }

case "${1:-}" in
    list)
        # Let cliphist resolve its own configured database location.
        error_file=$(mktemp)
        trap 'rm -f "$error_file"' EXIT
        if history=$(cliphist list 2> "$error_file"); then
            :
        elif [[ "$(< "$error_file")" == 'opening db: please store something first' ]]; then
            exit 0
        else
            cat "$error_file" >&2
            exit 1
        fi
        [[ -n "$history" ]] || exit 0
        thumbnail_dir="${XDG_CACHE_HOME:-$HOME/.cache}/cat/clipboard"
        umask 077
        mkdir -p "$thumbnail_dir"
        declare -A present=()
        while IFS=$'\t' read -r entry_id entry_preview; do
            [[ "$entry_id" =~ ^[0-9]+$ ]] || continue
            present["$entry_id"]=1
            image_path=""
            if [[ "$entry_preview" =~ ^\[\[\ binary\ data\ .*\ ([[:alnum:]]+)\ [0-9]+x[0-9]+\ \]\]$ ]]; then
                image_format="${BASH_REMATCH[1],,}"
                case "$image_format" in
                    png|jpg|jpeg|webp|gif|bmp|tif|tiff|jxl)
                        image_path="$thumbnail_dir/$entry_id.$image_format"
                        if [[ ! -s "$image_path" ]]; then
                            temporary_image="$image_path.tmp.$$"
                            if printf '%s' "$entry_id" | cliphist decode > "$temporary_image" 2>/dev/null; then
                                mv -f -- "$temporary_image" "$image_path"
                            else
                                rm -f -- "$temporary_image"
                                image_path=""
                            fi
                        fi
                        ;;
                    *) image_path="" ;;
                esac
            fi
            printf '%s\t%s\t%s\n' "$entry_id" "$entry_preview" "$image_path"
        done <<< "$history"
        for cached_image in "$thumbnail_dir"/*; do
            [[ -f "$cached_image" ]] || continue
            cached_id="${cached_image##*/}"
            cached_id="${cached_id%%.*}"
            [[ -v "present[$cached_id]" ]] || rm -f -- "$cached_image"
        done
        ;;
    copy|delete)
        [[ "${2:-}" =~ ^[0-9]+$ ]] || { echo 'Invalid clipboard entry.' >&2; exit 1; }
        if [[ "$1" == delete ]]; then
            printf '%s' "$2" | cliphist delete
            thumbnail_dir="${XDG_CACHE_HOME:-$HOME/.cache}/cat/clipboard"
            rm -f -- "$thumbnail_dir/$2".*
        else
            command -v wl-copy >/dev/null || { echo 'Install wl-clipboard to copy entries.' >&2; exit 1; }
            # Decode first so a failed lookup cannot replace the clipboard with empty data.
            tmp=$(mktemp)
            trap 'rm -f "$tmp"' EXIT
            printf '%s' "$2" | cliphist decode > "$tmp"
            wl-copy < "$tmp"
        fi
        ;;
    wipe)
        cliphist wipe
        thumbnail_dir="${XDG_CACHE_HOME:-$HOME/.cache}/cat/clipboard"
        rm -f -- "$thumbnail_dir"/*
        ;;
    *) echo 'Usage: clipboard.sh {list|copy ID|delete ID|wipe}' >&2; exit 2 ;;
esac
