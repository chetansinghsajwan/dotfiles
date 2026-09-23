# ZLE widgets for direct git picker keybindings, chorded under alt-g.
# Kept separate from git.sh since ZLE/bindkey are zsh-only, while git.sh's
# functions are sourced into bash too.
#
# alt-g, not ctrl-g: zellij's default keymap grabs ctrl-g globally to switch
# to locked mode before it ever reaches the shell (see fzf.zsh).
#
# These share the alt-g prefix with fzf.zsh's fuzzy-menu widget ('\eg' alone).
# zsh waits up to $KEYTIMEOUT after a complete "\eg" match to see if the
# sequence continues, so alt-g still opens the menu when nothing follows.

fzf-git-branch-widget() { __fzf_insert_widget fgb; }
zle -N fzf-git-branch-widget
bindkey '\egb' fzf-git-branch-widget

fzf-git-tag-widget() { __fzf_insert_widget fgt; }
zle -N fzf-git-tag-widget
bindkey '\egt' fzf-git-tag-widget

fzf-git-log-widget() { __fzf_insert_widget fgl; }
zle -N fzf-git-log-widget
bindkey '\egc' fzf-git-log-widget
