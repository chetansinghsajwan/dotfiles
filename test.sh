#!/usr/bin/env bash

function __file_search() {
    fzf-tmux -p 80%,60% -- \
        --margin=1 \
        --border=rounded \
        --padding=1 \
        --layout=reverse \
        --preview-window=right:50%:border-rounded \
        --preview='bat --color=always --line-range :50 {} 2>/dev/null || ls -lah {}' \
        --multi \
        --cycle \
        --scheme=path \
        --bind='ctrl-d:preview-page-down,ctrl-u:preview-page-up' \
        --bind='ctrl-/:toggle-preview' \
        --header='Ctrl-D/U: scroll | Ctrl-/: toggle preview | Tab: select'
}

function __search() {
    fzf --popup h
}

__search
