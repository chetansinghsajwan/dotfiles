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
    # -R/-D ask tidy-viewer to drop row numbering and the "tv dim:" line,
    # but both are no-ops in the currently packaged tidy-viewer (1.8.93) -
    # kept for forward-compat, with the sed below doing the real work of
    # stripping the dimensions line and the constant leading/trailing
    # blank lines. -a forces color output: piper's child process never has
    # a real tty for tidy-viewer's own auto-detection to pick up, so color
    # is silently dropped without it.
    #
    # The row-number column isn't stripped even though -R claims to: with
    # color forced it's a real (colored) field on every data row, while
    # the header row only has a same-width blank indent in its place -
    # stripping one side would misalign the two, so both are left as-is.
    tv_args=(-R -D -a)
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
    # Unanchored: -a wraps the dimensions line's leading text in ANSI color
    # codes, so it no longer starts with a literal "tv dim:" right after
    # the margin.
    tidy-viewer "${tv_args[@]}" "$file_path" | sed -e '/^$/d' -e '/tv dim:/d'
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
