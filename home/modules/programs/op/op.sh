usage() {
    echo "usage: op <file>" >&2
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

open_tabular() {
    local file_path=$1
    exec csvlens "$file_path"
}

open_text() {
    local file_path=$1 mime=$2

    # file's own "text/binary" call, not the mime type list above, decides
    # whether this is editable text - covers text files under any of the
    # many text/* and application/* mimes (json, yaml, toml, ...).
    local encoding
    encoding=$(file --brief --mime-encoding -- "$file_path")
    if [[ "$encoding" != "binary" ]]; then
        exec "${EDITOR:-hx}" "$file_path"
    fi

    echo "op: unsupported file type: $file_path ($mime)" >&2
    exit 1
}

[[ $# -eq 1 ]] || usage

file_path=$1

if [[ ! -f "$file_path" ]]; then
    echo "op: not a file: $file_path" >&2
    exit 1
fi

mime=$(file --brief --mime-type -- "$file_path")

if is_tabular "$file_path" "$mime"; then
    open_tabular "$file_path"
else
    open_text "$file_path" "$mime"
fi
