# Shell pickers on `pick` (the shared picker). Sourced into bash and zsh;
# the zsh-only keybindings are in pickers.zsh. The git, docker, nixpkgs and
# clipboard modules add their own pickers the same way.

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

# fh - fuzzy history search: bash-highlighted, numbered, with when each command last ran.
# ctrl-x deletes the highlighted command from the history file and reopens the list.
function fh() {
    # Reads the history file directly instead of `fc -l` — fc only sees the
    # current shell's in-memory history, which is empty in a non-interactive
    # run. The path is substituted in at build time (see default.nix) rather
    # than read from $HISTFILE here, since $HISTFILE can be unset in some
    # calling contexts — that silently fell back to a stale ~/.zsh_history
    # rather than the real, configured history file.
    local histfile="@histfile@"
    local out key cmd
    while true; do
        # `: EPOCH:SECONDS;command` (extended history) becomes `EPOCH<TAB>command`; plain lines get `-`.
        # Newest first, and each command once (the kept copy is its most recent run).
        out=$(awk '{
                if (match($0, /^: [0-9]+:[0-9]+;/)) {
                    split(substr($0, 3, RLENGTH - 3), p, ":"); ts = p[1]; cmd = substr($0, RLENGTH + 1)
                } else { ts = "-"; cmd = $0 }
                print ts "\t" cmd
            }' "$histfile" | tac | awk -F'\t' '!seen[$2]++' |
            pick --title "Shell History" --syntax bash --numbers --timestamps --expect ctrl-x) || return $?
        key=$(printf '%s\n' "$out" | head -n 1)
        cmd=$(printf '%s\n' "$out" | tail -n +2)
        if [[ $key == ctrl-x && -n $cmd ]]; then
            # Remove every copy of the command, with or without a timestamp, and show the list again.
            CMD="$cmd" awk '{
                    line = $0
                    if (match(line, /^: [0-9]+:[0-9]+;/)) line = substr(line, RLENGTH + 1)
                    if (line != ENVIRON["CMD"]) print $0
                }' "$histfile" >"$histfile.tmp" && mv "$histfile.tmp" "$histfile"
            continue
        fi
        printf '%s\n' "$cmd"
        return 0
    done
}

