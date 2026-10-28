# ZLE widgets for direct git picker keybindings, chorded under alt-g.
# Kept separate from git.sh since ZLE/bindkey are zsh-only, while git.sh's
# functions are sourced into bash too.
#
# alt-g, not ctrl-g: zellij's default keymap grabs ctrl-g globally to switch
# to locked mode before it ever reaches the shell (see pickers.zsh).
#
# These share the alt-g prefix with pickers.zsh's fuzzy-menu widget ('\eg' alone).
# zsh waits up to $KEYTIMEOUT after a complete "\eg" match to see if the
# sequence continues, so alt-g still opens the menu when nothing follows.

pick-git-branch-widget() { __pick_insert_widget fgb; }
zle -N pick-git-branch-widget
bindkey '\egb' pick-git-branch-widget

pick-git-tag-widget() { __pick_insert_widget fgt; }
zle -N pick-git-tag-widget
bindkey '\egt' pick-git-tag-widget

pick-git-log-widget() { __pick_insert_widget fgl; }
zle -N pick-git-log-widget
bindkey '\egc' pick-git-log-widget
