# Fuzzy clipboard-history picker on `pick` (the shared picker, from the
# pickers module). Needs cliphist's watcher (wl-paste --watch cliphist store)
# running to actually have history to browse - wired into Hyprland's exec-once
# by this module when dotfiles.desktop.hyprland.enable is on.

# fcp - fuzzy clipboard history. Enter copies the entry to the clipboard (nothing
# is printed); ctrl-x deletes it from the history and reopens the list.
function fcp() {
    # cliphist decode/delete expect the whole "id<TAB>preview" line as it
    # comes out of `list`, so the preview uses the whole-line {} placeholder.
    # shellcheck disable=SC2016 # single-quoted: this is pick's preview command, expanded by pick itself
    local preview_cmd='f=$(mktemp); cliphist decode {} > "$f" 2>/dev/null; if file -b --mime-type "$f" | grep -q "^text/"; then bat --color=always -l txt "$f"; else file -b "$f"; fi; rm -f "$f"'

    local out key row
    while true; do
        out=$(cliphist list | pick --title "Clipboard History" --expect ctrl-x --preview-cmd "$preview_cmd")
        key=$(sed -n 1p <<<"$out")
        row=$(sed -n 2p <<<"$out")
        [[ -z $row ]] && return 0

        if [[ $key == ctrl-x ]]; then
            cliphist delete <<<"$row"
            continue
        fi
        cliphist decode <<<"$row" | wl-copy
        return 0
    done
}
