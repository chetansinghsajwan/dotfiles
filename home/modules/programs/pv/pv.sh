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
    exec tidy-viewer "$file_path"
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
