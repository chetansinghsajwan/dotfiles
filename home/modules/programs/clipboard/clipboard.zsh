# ZLE widget for the clipboard-history picker.
# Kept separate from clipboard.sh since ZLE/bindkey are zsh-only, while
# clipboard.sh's function is sourced into bash too.
#
# alt-y, not ctrl-y: zsh's emacs keymap binds alt-y to yank-pop, which
# nothing here relies on (same tradeoff as docker.zsh's alt-d). A single
# plain binding, not a chord like docker/nixpkgs, since there's only the one
# picker here.
#
# fcp copies the selection straight to the clipboard itself (via its own
# enter bind) rather than printing it, so this widget's usual LBUFFER-insert
# is a no-op - that's intentional, see clipboard.sh.

fzf-clipboard-widget() { __fzf_insert_widget fcp; }
zle -N fzf-clipboard-widget
bindkey '\ey' fzf-clipboard-widget
