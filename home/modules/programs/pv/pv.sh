usage() {
    echo "usage: pv <file>" >&2
    exit 1
}

is_tabular() {
    local file_path=$1 mime=$2
    case "$file_path" in
    *.csv | *.tsv | *.CSV | *.TSV) return 0 ;;
    esac
    case "$mime" in
    text/csv | text/tab-separated-values) return 0 ;;
    esac
    return 1
}

render_tabular() {
    local file_path=$1

    # -D blanks out the "tv dim:" text (leaving an empty-ish line, cleaned
    # up below). Row numbering (bat's --style=numbers equivalent) is left
    # on. -a forces color output: piper's child process never has a real
    # tty for tidy-viewer's own auto-detection to pick up, so color is
    # silently dropped without it.
    local tv_args=(-D -a)
    if [[ -n "${h:-}" ]]; then
        # yazi's piper previewer sets $h to the preview pane's visible row
        # count. Once the sed below strips the blank lines and dimensions
        # line, only the header row and (when truncating) a trailing
        # "... with N more rows" line remain as overhead - reserve those
        # two so -n's row count, and the column widths computed from it,
        # match exactly what will be shown instead of overflowing and
        # getting cut off mid-table by piper's own line-count limit.
        local rows=$((h - 2))
        [[ "$rows" -lt 1 ]] && rows=1
        tv_args+=(-n "$rows")
    fi

    # -D blanks the dimensions line's text but leaves its width as plain
    # spaces, and tidy-viewer always wraps the table in a leading/trailing
    # blank line - drop anything that's empty or whitespace-only once
    # those get through.
    tidy-viewer "${tv_args[@]}" "$file_path" | sed -e '/^[[:space:]]*$/d'
}

render_text() {
    local file_path=$1 mime=$2

    # file's own "text/binary" call, not the mime type list above, decides
    # whether bat can handle it - covers text files under any of the many
    # text/* and application/* mimes bat already knows how to syntax-highlight.
    local encoding
    encoding=$(file --brief --mime-encoding -- "$file_path")
    if [[ "$encoding" != "binary" ]]; then
        exec bat --color=always --style=numbers --paging=never -- "$file_path"
    fi

    echo "pv: unsupported file type: $file_path ($mime)" >&2
    exit 1
}

[[ $# -eq 1 ]] || usage

file_path=$1

if [[ ! -f "$file_path" ]]; then
    echo "pv: not a file: $file_path" >&2
    exit 1
fi

mime=$(file --brief --mime-type -- "$file_path")

if is_tabular "$file_path" "$mime"; then
    render_tabular "$file_path"
else
    render_text "$file_path" "$mime"
fi
