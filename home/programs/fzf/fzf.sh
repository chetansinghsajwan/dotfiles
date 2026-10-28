# Base fzf wrapper
function __fzf() {
    local label=""
    local multi=1

    # Parse named options
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --label)
            label="$2"
            shift 2
            ;;
        --no-multi)
            multi=0
            shift
            ;;
        --)
            shift
            break
            ;; # remaining args passed straight to fzf
        *) break ;;
        esac
    done

    # Tracks current multi/single-select state across alt-m presses;
    # fzf has no native "toggle-multi" action, only change-multi (on/off).
    # alt-m, not ctrl-t: zellij's default keymap grabs ctrl-t globally to
    # enter tab mode before it ever reaches fzf.
    local multi_state
    multi_state=$(mktemp)
    echo "$multi" >"$multi_state"

    local multi_toggle_bind="alt-m:transform:if [ \"\$(cat '$multi_state')\" = 1 ]; then printf 0 > '$multi_state'; echo 'change-multi(0)'; else printf 1 > '$multi_state'; echo 'change-multi'; fi"

    # Static defaults (popup size, border, layout, preview window, the
    # constant binds) live in programs.fzf.defaultOptions (-> FZF_DEFAULT_OPTS)
    # instead of here; only the per-invocation dynamic bits stay in this array.
    local args=(
        --bind "$multi_toggle_bind"
    )

    [[ -n $label ]] && args+=(--border-label " $label ")
    [[ $multi -eq 1 ]] && args+=(--multi)

    # Any leftover args (after --) get appended, allowing overrides/extras
    fzf "${args[@]}" "$@"

    rm -f "$multi_state"
}

# The pickers below run on `pick` (the shared picker, see plan.md). `__fzf`
# above stays for the modules that still need fzf-only features.

# ff - fuzzy file search; -d/--dirs also lists folders
function ff() {
    local search_dir="."
    local args=(--title "Files")

    while [[ $# -gt 0 ]]; do
        case "$1" in
        -d | --dirs)
            args+=(--dirs)
            shift
            ;;
        *)
            search_dir="$1"
            shift
            ;;
        esac
    done

    pick --files "$search_dir" "${args[@]}"
}

# fs - live text search across file contents (regex, smart case)
function fs() {
    pick --grep "${1:-.}" --title "Text Search"
}

# fp - fuzzy process search
function fp() {
    ps -eo pid,ppid,user,pcpu,pmem,etime,comm --sort=-pcpu | tail -n +2 | pick \
        --title "Processes" \
        --preview-cmd 'ps -p {1} -o pid,ppid,user,stat,pcpu,pmem,etime,args --no-headers'
}

# fe - fuzzy environment variable search
function fe() {
    env | sort | pick \
        --title "Environment" \
        --delimiter '=' \
        --preview-cmd 'echo {2..} | tr : "\n"'
}

# fcmd - fuzzy search available commands (builtins, functions, aliases, PATH executables)
function fcmd() {
    {
        if [[ -n $ZSH_VERSION ]]; then
            # (@ok) is zsh-only associative-array-key expansion syntax, invalid
            # under shellcheck/shfmt's bash parser — excluded from shfmt in
            # treefmt.nix for that reason; disabled here for the same reason.
            # shellcheck disable=SC2296
            print -rl -- "${(@ok)commands}" "${(@ok)functions}" "${(@ok)aliases}" "${(@ok)reswords}"
        else
            compgen -c
        fi
    } | sort -u | pick \
        --title "Commands" \
        --preview-cmd 'type {1} 2>/dev/null'
}

# fssh - fuzzy ssh host search
function fssh() {
    awk '/^Host / {for (i=2;i<=NF;i++) if ($i !~ /[*?]/) print $i}' ~/.ssh/config 2>/dev/null |
        sort -u | pick \
        --title "SSH Hosts" \
        --preview-cmd 'awk -v h={1} '\''/^Host / {p=0; for (i=2;i<=NF;i++) if ($i==h) p=1} p'\'' ~/.ssh/config'
}

# fh - fuzzy history search
function fh() {
    # Reads the history file directly instead of `fc -l` — fc only sees the
    # current shell's in-memory history, which is empty in a non-interactive
    # run. The path is substituted in at build time (see default.nix) rather
    # than read from $HISTFILE here, since $HISTFILE can be unset in some
    # calling contexts — that silently fell back to a stale ~/.zsh_history
    # rather than the real, configured history file.
    local histfile="@histfile@"
    # tac before dedup so the kept copy of a repeated command is its most
    # recent run, not its first-ever one.
    sed -E 's/^: [0-9]+:[0-9]+;//' "$histfile" | tac | awk '!seen[$0]++' | pick --title "History"
}

# fgl / fgb / fgs - git commits, branches and tags, stashes (in the current repo)
function fgl() { pick --git commits --title "Commits"; }
function fgb() { pick --git refs --title "Branches and Tags"; }
function fgs() { pick --git stashes --title "Stashes"; }
