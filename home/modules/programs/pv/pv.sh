if [ $# -ne 1 ]; then
    echo "usage: pv <file>" >&2
    exit 1
fi

file_path=$1

if [ ! -f "$file_path" ]; then
    echo "pv: not a file: $file_path" >&2
    exit 1
fi

is_tabular=0
case "$file_path" in
*.csv | *.tsv | *.CSV | *.TSV) is_tabular=1 ;;
esac

mime=$(file --brief --mime-type -- "$file_path")
case "$mime" in
text/csv | text/tab-separated-values) is_tabular=1 ;;
esac

if [ "$is_tabular" -eq 1 ]; then
    # -D blanks out the "tv dim:" text (leaving an empty-ish line, cleaned
    # up below). Row numbering (bat's --style=numbers equivalent) is left
    # on. -a forces color output: piper's child process never has a real
    # tty for tidy-viewer's own auto-detection to pick up, so color is
    # silently dropped without it.
    tv_args=(-D -a)
    if [ -n "${h:-}" ]; then
        # yazi's piper previewer sets $h to the preview pane's visible row
        # count. Once the sed below strips the blank lines and dimensions
        # line, only the header row and (when truncating) a trailing
        # "... with N more rows" line remain as overhead - reserve those
        # two so -n's row count, and the column widths computed from it,
        # match exactly what will be shown instead of overflowing and
        # getting cut off mid-table by piper's own line-count limit.
        rows=$((h - 2))
        [ "$rows" -lt 1 ] && rows=1
        tv_args+=(-n "$rows")
    fi
    # -D blanks the dimensions line's text but leaves its width as plain
    # spaces, and tidy-viewer always wraps the table in a leading/trailing
    # blank line - drop anything that's empty or whitespace-only once
    # those get through.
    tidy-viewer "${tv_args[@]}" "$file_path" | sed -e '/^[[:space:]]*$/d'
    exit
fi

# file's own "text/binary" call, not the mime type list above, decides
# whether bat can handle it - covers text files under any of the many
# text/* and application/* mimes bat already knows how to syntax-highlight.
encoding=$(file --brief --mime-encoding -- "$file_path")
if [ "$encoding" != "binary" ]; then
    exec bat --color=always --style=numbers --paging=never -- "$file_path"
fi

echo "pv: unsupported file type: $file_path ($mime)" >&2
exit 1
