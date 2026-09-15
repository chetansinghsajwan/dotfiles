# ZLE widgets for direct docker picker keybindings, chorded under alt-d.
# Kept separate from docker.sh since ZLE/bindkey are zsh-only, while docker.sh's
# functions are sourced into bash too.
#
# alt-d, not ctrl-d: ctrl-d is already claimed inside the fdps picker itself
# (toggle running/all), and zsh's emacs keymap only binds alt-d to
# kill-word, which nothing here relies on.
#
# zsh waits up to $KEYTIMEOUT after a complete "\ed" match to see if the
# sequence continues, so plain alt-d still falls through to kill-word when
# nothing follows (same trick as fzf.zsh's alt-g menu vs git.zsh's chords).

fzf-docker-ps-widget() { __fzf_insert_widget fdps }
zle -N fzf-docker-ps-widget
bindkey '\edp' fzf-docker-ps-widget

fzf-docker-images-widget() { __fzf_insert_widget fdimg }
zle -N fzf-docker-images-widget
bindkey '\edi' fzf-docker-images-widget

fzf-docker-volumes-widget() { __fzf_insert_widget fdvol }
zle -N fzf-docker-volumes-widget
bindkey '\edv' fzf-docker-volumes-widget

fzf-docker-networks-widget() { __fzf_insert_widget fdnet }
zle -N fzf-docker-networks-widget
bindkey '\edn' fzf-docker-networks-widget
