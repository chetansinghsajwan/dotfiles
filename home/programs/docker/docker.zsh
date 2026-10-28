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
# nothing follows (same trick as pickers.zsh's alt-g menu vs git.zsh's chords).

pick-docker-ps-widget() { __pick_insert_widget fdps; }
zle -N pick-docker-ps-widget
bindkey '\edp' pick-docker-ps-widget

pick-docker-images-widget() { __pick_insert_widget fdimg; }
zle -N pick-docker-images-widget
bindkey '\edi' pick-docker-images-widget

pick-docker-volumes-widget() { __pick_insert_widget fdvol; }
zle -N pick-docker-volumes-widget
bindkey '\edv' pick-docker-volumes-widget

pick-docker-networks-widget() { __pick_insert_widget fdnet; }
zle -N pick-docker-networks-widget
bindkey '\edn' pick-docker-networks-widget
