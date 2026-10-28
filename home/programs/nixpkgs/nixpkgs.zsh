# ZLE widgets for direct nixpkgs picker keybindings, chorded under alt-n.
# Kept separate from nixpkgs.sh since ZLE/bindkey are zsh-only, while
# nixpkgs.sh's functions are sourced into bash too.
#
# alt-n, not ctrl-n: zsh's emacs keymap binds alt-n to down-line-or-history,
# which nothing here relies on (same tradeoff as docker.zsh's alt-d).
#
# fnp prompts interactively for a search term when called with no args (see
# nixpkgs.sh), which still works fine run this way through a ZLE widget.

pick-nix-packages-widget() { __pick_insert_widget fnp; }
zle -N pick-nix-packages-widget
bindkey '\enp' pick-nix-packages-widget

pick-nix-installed-widget() { __pick_insert_widget fnpi; }
zle -N pick-nix-installed-widget
bindkey '\eni' pick-nix-installed-widget
