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
    if [[ -n ${h:-} ]]; then
        # yazi's piper previewer sets $h to the preview pane's visible row
        # count. Once the sed below strips the blank lines and dimensions
        # line, only the header row and (when truncating) a trailing
        # "... with N more rows" line remain as overhead - reserve those
        # two so -n's row count, and the column widths computed from it,
        # match exactly what will be shown instead of overflowing and
        # getting cut off mid-table by piper's own line-count limit.
        local rows=$((h - 2))
        [[ $rows -lt 1 ]] && rows=1
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
    # A zero-byte file has no content to sample, so file always calls its
    # encoding "binary" - treat it as text since there's nothing it could
    # disagree with.
    local encoding
    encoding=$(file --brief --dereference --mime-encoding -- "$file_path")
    if [[ $encoding != "binary" || ! -s $file_path ]]; then
        exec bat --color=always --style=numbers,changes --paging=never -- "$file_path"
    fi

    echo "pv: unsupported file type: $file_path ($mime)" >&2
    exit 1
}

[[ $# -eq 1 ]] || usage

file_path=$1

if [[ -d $file_path ]]; then
    # A compact preview, not the full tree: the folder's own entries, and under
    # each subfolder at most two of its entries, then a "…" marker if more exist.
    # Directories sort first so piper's line-count cutoff keeps them in view.
    # eza prints the root as the first line; skip it so only the contents show.
    #
    # Each entry also gets permissions + relative mtime flush right, styled like
    # yazi's `perm_time` linemode. eza can't render those that way itself, so a
    # second plain `-l` listing (same order, one line per entry) supplies the raw
    # perm string and epoch mtime, and awk joins the two by line number.
    # $w is yazi/piper's preview-pane width; fall back to the terminal's.
    width=${w:-$(tput cols 2>/dev/null || echo 80)}
    LC_ALL=C.UTF-8 awk -v width="$width" '
        function relative(t,    diff) {
            diff = systime() - t
            if (t == 0) return "-"
            if (diff < 60) return "now"
            if (diff < 3600) return int(diff / 60) "m ago"
            if (diff < 86400) return int(diff / 3600) "h ago"
            if (diff < 86400 * 30) return int(diff / 86400) "d ago"
            if (diff < 86400 * 365) return int(diff / (86400 * 30)) "mo ago"
            return strftime("%Y", t)
        }
        # Same palette as the yazi linemode in init.lua: owner bits coloured, group/other
        # dimmed, setuid/setgid/sticky highlighted.
        function perm_span(ch, is_owner) {
            if (ch ~ /[sStT]/) return "\033[1;35m" ch "\033[0m"
            if (!is_owner) return "\033[90m" ch "\033[0m"
            if (ch == "r") return "\033[32m" ch "\033[0m"
            if (ch == "w") return "\033[33m" ch "\033[0m"
            if (ch == "x") return "\033[31m" ch "\033[0m"
            return "\033[90m" ch "\033[0m"
        }
        # Collapse the two-column git status from eza (staged, unstaged) into the single
        # sign the yazi git plugin would show, using its priority order: ignored >
        # untracked > unstaged > staged > added > deleted > updated. Signs and
        # colours mirror theme.git in yazi.nix; clean/unknown is a blank cell.
        function git_sign(st,    s, u) {
            if (st !~ /^[-NMDRTIU][-NMDRTIU]$/) return " "
            s = substr(st, 1, 1); u = substr(st, 2, 1)
            if (s == "I" || u == "I") return "\033[90m!\033[0m"
            if (u == "N") return "\033[35m?\033[0m"
            if (u == "M" || u == "T") return "\033[33mM\033[0m"
            if (s == "M" || s == "T" || s == "R") return "\033[32m+\033[0m"
            if (s == "N") return "\033[32mA\033[0m"
            if (s == "D" || u == "D") return "\033[31mD\033[0m"
            if (s == "U" || u == "U") return "\033[33mU\033[0m"
            return " "
        }
        function right_column(meta,    bits, out, i) {
            bits = substr(meta[1], 2, 9)
            out = ""
            for (i = 1; i <= 9; i++) {
                out = out perm_span(substr(bits, i, 1), i <= 3)
                if (i == 3 || i == 6) out = out " "
            }
            return out "  " sprintf("\033[90m%8s\033[0m", relative(meta[2])) " " git_sign(meta[3])
        }
        # Reserved width of the right column: 9 perm chars + 2 gaps + 2 spaces + 8 time
        # + 1 space + 1 git sign, plus 2 cells of padding before the pane edge.
        BEGIN { right_width = 25 }
        # First stream: the plain `-l` listing, kept by line number.
        NR == FNR { meta_line[FNR] = $0; next }
        {
            plain = $0
            gsub(/\033\[[0-9;]*m/, "", plain)
        }
        # Top-level entries start with a branch glyph; second-level ones are indented.
        plain ~ /^(├|└)── / { shown = 0; skipping = 0; emit($0, plain, FNR); next }
        skipping { next }
        shown >= 2 {
            indent = (plain ~ /^│/) ? "│   " : "    "
            printf "\033[1;90m%s└── …\033[0m\n", indent
            skipping = 1
            next
        }
        { shown++; emit($0, plain, FNR) }
        function emit(line, plain_line, n,    split_meta, pad) {
            split(meta_line[n], split_meta, " ")
            pad = width - length(plain_line) - right_width
            if (pad < 1) pad = 1
            printf "%s%*s%s\n", line, pad, "", right_column(split_meta)
        }
    ' \
        <(eza --tree --level=2 -l --no-user --no-filesize --git --time-style=+%s --color=never --group-directories-first -- "$file_path" | tail -n +2) \
        <(eza --tree --level=2 --color=always --icons=always --group-directories-first -- "$file_path" | tail -n +2)
    exit 0
fi

if [[ ! -f $file_path ]]; then
    echo "pv: not a file: $file_path" >&2
    exit 1
fi

mime=$(file --brief --dereference --mime-type -- "$file_path")

if is_tabular "$file_path" "$mime"; then
    render_tabular "$file_path"
else
    render_text "$file_path" "$mime"
fi
