# Fuzzy clipboard-history picker built on the __fzf wrapper from the fzf
# module. Needs cliphist's watcher (wl-paste --watch cliphist store) running
# to actually have history to browse - wired into Hyprland's exec-once by
# this module when dotfiles.desktop.hyprland.enable is on.

# fcp - fuzzy clipboard history
function fcp() {
    # cliphist decode/delete expect the whole "id<TAB>preview" line as it
    # comes out of `list`, not just the id field - so preview/binds use
    # fzf's whole-line {} placeholder throughout, never {1}.
    # shellcheck disable=SC2016 # single-quoted: this is fzf's preview command, expanded by fzf itself
    local preview_cmd='f=$(mktemp); cliphist decode {} > "$f" 2>/dev/null; if file -b --mime-type "$f" | grep -q "^text/"; then bat --color=always -l txt "$f"; else file -b "$f"; fi; rm -f "$f"'

    cliphist list | __fzf \
        --label "Clipboard History" \
        --no-multi \
        -- \
        --preview "$preview_cmd" \
        --preview-window 'right:60%:noborder:wrap' \
        --bind 'enter:execute-silent(cliphist decode {} | wl-copy)+abort' \
        --bind 'ctrl-x:execute-silent(cliphist delete {})+reload(cliphist list)'
}
