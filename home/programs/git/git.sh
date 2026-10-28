# Fuzzy git pickers on `pick` (the shared picker, from the pickers module).
# Commits, branches and stashes use pick's own git sources, which preview the
# commit with its patch; the rest feed git's output to pick with a preview command.

# fgl - fuzzy git log (commits); prints the full commit hash
function fgl() { pick --git commits --title "Git Commits"; }

# fgb - fuzzy branches and tags; prints the name
function fgb() { pick --git refs --title "Git Branches and Tags"; }

# fgt - fuzzy git tag
function fgt() {
    git tag | pick \
        --title "Git Tags" \
        --preview-cmd 'git log --oneline --color=always {1} | head -50'
}

# fgs - fuzzy git stash; prints stash@{n}
function fgs() { pick --git stashes --title "Git Stashes"; }

# fgst - fuzzy git status
function fgst() {
    git status --short | pick \
        --title "Git Status" \
        --preview-cmd 'git diff --color=always HEAD -- {2}'
}

# fglf - fuzzy git log for a chosen file
function fglf() {
    local file
    file=$(pick --files --title "Pick File" | head -n 1)
    [[ -z $file ]] && return

    git log --oneline --follow -- "$file" | pick \
        --title "Log: $file" \
        --preview-cmd "git show --color=always {1} -- '$file'"
}

# fgr - fuzzy git reflog
function fgr() {
    git reflog | pick \
        --title "Git Reflog" \
        --preview-cmd 'git show --color=always {1}'
}
