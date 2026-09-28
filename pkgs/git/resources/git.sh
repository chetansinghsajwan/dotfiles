# Fuzzy git pickers built on the __fzf wrapper from the fzf module (fzf's
# own home-manager module is always installed, independent of git).

# fgl - fuzzy git log (commits)
function fgl() {
    # Tracks which preview (full diff vs stat) is active across ctrl-g presses;
    # fzf has no native "toggle-preview-command" action, only change-preview.
    local preview_state
    preview_state=$(mktemp)
    echo 0 >"$preview_state"

    local preview0="git show --color=always {1}"
    local preview1="git show --color=always --stat {1}"

    local preview_toggle_bind="ctrl-g:transform:if [ \"\$(cat '$preview_state')\" = 0 ]; then printf 1 > '$preview_state'; echo 'change-preview($preview1)'; else printf 0 > '$preview_state'; echo 'change-preview($preview0)'; fi"

    git log --oneline --color=always | __fzf \
        --label "Git Commits" \
        -- \
        --ansi \
        --preview "$preview0" \
        --bind "$preview_toggle_bind"

    rm -f "$preview_state"
}

# fgb - fuzzy git branch
function fgb() {
    # Branch name yellow, relative commit date green, subject blue - git's
    # own --color=always default for `git branch` barely colors anything, so
    # this uses an explicit --format instead (same scheme as junegunn/fzf-git.sh).
    git branch --all --color=always \
        --format=$'%(HEAD) %(color:yellow)%(refname:short) %(color:green)(%(committerdate:relative))\t%(color:blue)%(subject)%(color:reset)' |
        column -t -s $'\t' |
        __fzf --label "Git Branches" -- \
            --ansi \
            --preview "git log --oneline --color=always \$(cut -c3- <<< {} | cut -d' ' -f1) | head -50"
}

# fgt - fuzzy git tag
function fgt() {
    git tag --color=always |
        __fzf --label "Git Tags" -- \
            --ansi \
            --preview 'git log --oneline --color=always {1} | head -50'
}

# fgs - fuzzy git stash
function fgs() {
    # shellcheck disable=SC2016 # single-quoted: this is fzf's preview command, expanded by fzf itself
    git stash list --color=always | __fzf \
        --label "Git Stashes" \
        -- \
        --ansi \
        --preview 's={1}; git stash show -p --color=always "${s%:}"'
}

# fgst - fuzzy git status
function fgst() {
    git -c color.status=always status --short | __fzf \
        --label "Git Status" \
        -- \
        --ansi \
        --preview 'git diff --color=always HEAD -- {2}'
}

# fglf - fuzzy git log for a chosen file
function fglf() {
    local file
    file=$(rg --files | __fzf --label "Pick File" --no-multi)
    [[ -z $file ]] && return

    git log --oneline --color=always --follow -- "$file" | __fzf \
        --label "Log: $file" \
        -- \
        --ansi \
        --preview "git show --color=always {1} -- '$file'"
}

# fgr - fuzzy git reflog
function fgr() {
    git reflog --color=always | __fzf \
        --label "Git Reflog" \
        -- \
        --ansi \
        --preview 'git show --color=always {1}'
}
