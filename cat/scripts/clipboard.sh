#!/usr/bin/env bash
set -euo pipefail

command -v cliphist >/dev/null || { echo 'Install cliphist to use clipboard history.' >&2; exit 1; }

thumbnail_dir="${XDG_CACHE_HOME:-$HOME/.cache}/cat/clipboard"
temporary_files=()
umask 077

cleanup() {
    if (( ${#temporary_files[@]} )); then
        rm -f -- "${temporary_files[@]}"
    fi
}
trap cleanup EXIT

list_entries() {
    local error_file history entry_id entry_preview image_format image_path
    local temporary_image cached_image cached_name
    local -A present=()

    # Let cliphist resolve its own configured database location.
    error_file=$(mktemp)
    temporary_files+=("$error_file")
    if history=$(cliphist list 2> "$error_file"); then
        :
    elif [[ "$(< "$error_file")" == 'opening db: please store something first' ]]; then
        history=""
    else
        cat "$error_file" >&2
        return 1
    fi

    mkdir -p -- "$thumbnail_dir"
    while IFS=$'\t' read -r entry_id entry_preview; do
        [[ "$entry_id" =~ ^[0-9]+$ ]] || continue
        image_path=""
        if [[ "$entry_preview" =~ ^\[\[\ binary\ data\ .*\ ([[:alnum:]]+)\ [0-9]+x[0-9]+\ \]\]$ ]]; then
            image_format="${BASH_REMATCH[1],,}"
            case "$image_format" in
                png|jpg|jpeg|webp|gif|bmp|tif|tiff|jxl)
                    image_path="$thumbnail_dir/$entry_id.$image_format"
                    if [[ ! -s "$image_path" ]]; then
                        temporary_image=$(mktemp "$thumbnail_dir/.preview.XXXXXX")
                        temporary_files+=("$temporary_image")
                        if printf '%s' "$entry_id" | cliphist decode > "$temporary_image" 2>/dev/null; then
                            mv -f -- "$temporary_image" "$image_path"
                        else
                            image_path=""
                        fi
                    fi
                    if [[ -n "$image_path" ]]; then
                        present["${image_path##*/}"]=1
                    fi
                    ;;
            esac
        fi
        printf '%s\t%s\t%s\n' "$entry_id" "$entry_preview" "$image_path"
    done <<< "$history"

    # Empty or externally cleared histories must also remove cached images.
    for cached_image in "$thumbnail_dir"/*; do
        [[ -f "$cached_image" ]] || continue
        cached_name="${cached_image##*/}"
        if [[ ! ${present["$cached_name"]+present} ]]; then
            rm -f -- "$cached_image"
        fi
    done
}

copy_entry() {
    local temporary_copy
    command -v wl-copy >/dev/null || { echo 'Install wl-clipboard to copy entries.' >&2; return 1; }
    # Decode first so a failed lookup cannot replace the clipboard with empty data.
    temporary_copy=$(mktemp)
    temporary_files+=("$temporary_copy")
    printf '%s' "$1" | cliphist decode > "$temporary_copy"
    wl-copy < "$temporary_copy"
}

case "${1:-}" in
    list) list_entries ;;
    copy|delete)
        [[ "${2:-}" =~ ^[0-9]+$ ]] || { echo 'Invalid clipboard entry.' >&2; exit 1; }
        if [[ "$1" == copy ]]; then
            copy_entry "$2"
        else
            printf '%s' "$2" | cliphist delete
            rm -f -- "$thumbnail_dir/$2".*
        fi
        ;;
    wipe)
        cliphist wipe
        rm -f -- "$thumbnail_dir"/*
        ;;
    *) echo 'Usage: clipboard.sh {list|copy ID|delete ID|wipe}' >&2; exit 2 ;;
esac
