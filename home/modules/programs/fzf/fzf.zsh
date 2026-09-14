# ZLE widgets wiring fzf.sh's picker functions into zsh keybindings.
# Kept separate from fzf.sh since ZLE/bindkey are zsh-only, while fzf.sh's
# functions are sourced into bash too.

__fzf_insert_widget() {
    local result
    result=$("$1")
    [[ -n "$result" ]] && LBUFFER="${LBUFFER}${result}"
    zle reset-prompt
}

fzf-file-widget() { __fzf_insert_widget ff }
zle -N fzf-file-widget
# alt-t, not ctrl-t: zellij's default keymap grabs ctrl-t globally to enter
# tab mode before it ever reaches the shell.
bindkey '\et' fzf-file-widget

fzf-history-widget() { __fzf_insert_widget fh }
zle -N fzf-history-widget
bindkey '^R' fzf-history-widget

# home-manager's own fzf integration (programs.fzf.enableZshIntegration)
# binds alt-c to its own plain cd widget; override it to match the polish
# alt-t/ctrl-r get, and to actually cd instead of just inserting text.
fzf-cd-widget() {
    local dir
    dir=$(fd)
    [[ -n "$dir" ]] && cd -- "$dir"
    zle reset-prompt
}
zle -N fzf-cd-widget
bindkey '\ec' fzf-cd-widget

# Everything else lives behind one menu instead of claiming more ctrl-key
# slots — pick the picker, then its result is inserted like the above.
# Entries are only offered if their function is actually defined, since the
# git-specific pickers (fgl, fgb, ...) live in the git module and are only
# sourced when programs.git.enable is on.
__fzf_menu_dispatch() {
    local -a items=(
        "fgl   git log/commits"
        "fgb   git branch"
        "fgt   git tag"
        "fgs   git stash"
        "fgst  git status"
        "fglf  git log (file)"
        "fgr   git reflog"
        "fs    text search"
        "fp    process"
        "fe    env"
        "fssh  ssh host"
    )
    local -a available=()
    local item name
    for item in "${items[@]}"; do
        name="${item%% *}"
        (( $+functions[$name] )) && available+=("$item")
    done

    local choice
    choice=$(printf '%s\n' "${available[@]}" | __fzf --label "Fzf Menu" --no-multi)

    case "$choice" in
        fgl\ *)  fgl ;;
        fgb\ *)  fgb ;;
        fgt\ *)  fgt ;;
        fgs\ *)  fgs ;;
        fgst\ *) fgst ;;
        fglf\ *) fglf ;;
        fgr\ *)  fgr ;;
        fs\ *)   fs ;;
        fp\ *)   fp ;;
        fe\ *)   fe ;;
        fssh\ *) fssh ;;
    esac
}

fzf-menu-widget() { __fzf_insert_widget __fzf_menu_dispatch }
zle -N fzf-menu-widget
# alt-g, not ctrl-g: zellij's default keymap grabs ctrl-g globally to switch
# to locked mode before it ever reaches the shell.
bindkey '\eg' fzf-menu-widget
