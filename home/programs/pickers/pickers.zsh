# ZLE widgets wiring pickers.sh's picker functions (all `pick`-backed) into zsh
# keybindings. Kept separate from pickers.sh since ZLE/bindkey are zsh-only,
# while pickers.sh's functions are sourced into bash too.

__pick_insert_widget() {
    local result
    result=$("$1")
    [[ -n $result ]] && LBUFFER="${LBUFFER}${result}"
    zle reset-prompt
}

pick-file-widget() { __pick_insert_widget ff; }
zle -N pick-file-widget
# alt-t, not ctrl-t: zellij's default keymap grabs ctrl-t globally to enter
# tab mode before it ever reaches the shell.
bindkey '\et' pick-file-widget

pick-history-widget() { __pick_insert_widget fh; }
zle -N pick-history-widget
bindkey '^R' pick-history-widget

# alt-c: pick a folder and cd into it (instead of inserting its name).
pick-cd-widget() {
    local dir
    dir=$(pick --files --only-dirs --title "Directories")
    [[ -n $dir ]] && cd -- "$dir"
    zle reset-prompt
}
zle -N pick-cd-widget
bindkey '\ec' pick-cd-widget

# Everything else lives behind one menu instead of claiming more ctrl-key
# slots — pick the picker, then its result is inserted like the above.
__pick_menu_dispatch() {
    local -a items=(
        "fgl   git commits"
        "fgb   git branches and tags"
        "fgt   git tag"
        "fgs   git stashes"
        "fgst  git status"
        "fglf  git log (file)"
        "fgr   git reflog"
        "fs    text search"
        "fp    process"
        "fe    env"
        "fcmd  command"
        "fssh  ssh host"
    )
    local -a available=()
    local item name
    for item in "${items[@]}"; do
        name="${item%% *}"
        (($+functions[$name])) && available+=("$item")
    done

    local choice
    choice=$(printf '%s\n' "${available[@]}" | pick --title "Menu")

    case "$choice" in
    fgl\ *) fgl ;;
    fgb\ *) fgb ;;
    fgt\ *) fgt ;;
    fgs\ *) fgs ;;
    fgst\ *) fgst ;;
    fglf\ *) fglf ;;
    fgr\ *) fgr ;;
    fs\ *) fs ;;
    fp\ *) fp ;;
    fe\ *) fe ;;
    fcmd\ *) fcmd ;;
    fssh\ *) fssh ;;
    esac
}

pick-menu-widget() { __pick_insert_widget __pick_menu_dispatch; }
zle -N pick-menu-widget
# alt-g, not ctrl-g: zellij's default keymap grabs ctrl-g globally to switch
# to locked mode before it ever reaches the shell.
bindkey '\eg' pick-menu-widget
