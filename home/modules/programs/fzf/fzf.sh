# Base fzf wrapper
function __fzf() {
    local label=""
    local multi=1

    # Parse named options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --label)   label="$2"; shift 2 ;;
            --no-multi) multi=0; shift ;;
            --) shift; break ;;   # remaining args passed straight to fzf
            *) break ;;
        esac
    done

    # Tracks current multi/single-select state across alt-m presses;
    # fzf has no native "toggle-multi" action, only change-multi (on/off).
    # alt-m, not ctrl-t: zellij's default keymap grabs ctrl-t globally to
    # enter tab mode before it ever reaches fzf.
    local multi_state
    multi_state=$(mktemp)
    echo "$multi" > "$multi_state"

    local multi_toggle_bind="alt-m:transform:if [ \"\$(cat '$multi_state')\" = 1 ]; then printf 0 > '$multi_state'; echo 'change-multi(0)'; else printf 1 > '$multi_state'; echo 'change-multi'; fi"

    # Static defaults (popup size, border, layout, preview window, the
    # constant binds) live in programs.fzf.defaultOptions (-> FZF_DEFAULT_OPTS)
    # instead of here; only the per-invocation dynamic bits stay in this array.
    local args=(
        --bind "$multi_toggle_bind"
    )

    [[ -n "$label" ]] && args+=(--border-label " $label ")
    [[ "$multi" -eq 1 ]] && args+=(--multi)

    # Any leftover args (after --) get appended, allowing overrides/extras
    fzf "${args[@]}" "$@"

    rm -f "$multi_state"
}

# ff - fuzzy file search
function ff() {
    local start_mode=0
    local search_dir="."

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dirs) start_mode=1; shift ;;
            *) search_dir="$1"; shift ;;
        esac
    done

    # Tracks which search mode (files vs dirs) is active across ctrl-d presses;
    # fzf has no native "toggle-search-mode" action, so we reload the list and
    # let a mode-aware --preview command pick the right previewer at render time.
    # (A change-preview baked into the same transform as reload would resolve {}
    # against the stale pre-reload selection instead of the new item.)
    local mode_state
    mode_state=$(mktemp)
    echo "$start_mode" > "$mode_state"

    local files_cmd="fd --type f --type l --base-directory '$search_dir'"
    local dirs_cmd="fd --type d --type l --base-directory '$search_dir'"
    local file_preview="bat --color=always --line-range :50 --style=numbers '$search_dir'/{}"
    local dir_preview="eza -lah --color=always --icons=always --git '$search_dir'/{}"
    local preview_cmd="if [ \"\$(cat '$mode_state')\" = 1 ]; then $dir_preview; else $file_preview; fi"

    local mode_toggle_bind="ctrl-d:transform:if [ \"\$(cat '$mode_state')\" = 0 ]; then printf 1 > '$mode_state'; echo 'reload($dirs_cmd)'; else printf 0 > '$mode_state'; echo 'reload($files_cmd)'; fi"

    local init_cmd="$files_cmd"
    [[ "$start_mode" -eq 1 ]] && init_cmd="$dirs_cmd"

    eval "$init_cmd" | __fzf \
        --label "Files" \
        -- \
        --preview "$preview_cmd" \
        --bind "$mode_toggle_bind" \
        --bind "ctrl-e:become(\${EDITOR:-nvim} '$search_dir'/{})"

    rm -f "$mode_state"
}

# fs - fuzzy text search (live ripgrep across file contents)
function fs() {
    local search_dir="."
    [[ -n "$1" ]] && search_dir="$1"

    # "." would make rg print a "./" prefix on every path (same issue ff hit
    # with find/fd), so only pass a path arg when searching outside pwd.
    local rg_cmd="rg --column --line-number --no-heading --color=always --smart-case --"
    if [[ "$search_dir" != "." ]]; then
        rg_cmd="$rg_cmd {q} '$search_dir'"
    else
        rg_cmd="$rg_cmd {q}"
    fi

    # --disabled hands filtering to rg (reloaded on every keystroke) instead
    # of fzf's own fuzzy matcher, since rg is doing real regex search here.
    : | __fzf \
        --label "Text Search" \
        --no-multi \
        -- \
        --ansi \
        --disabled \
        --delimiter : \
        --bind "start:reload:$rg_cmd" \
        --bind "change:reload:sleep 0.1; $rg_cmd || true" \
        --preview 'bat --color=always --highlight-line {2} {1}' \
        --preview-window 'right:60%:noborder:+{2}-5' \
        --bind "ctrl-e:become(\${EDITOR:-nvim} +{2} {1})"
}

# fp - fuzzy process search
function fp() {
    ps -eo pid,ppid,user,pcpu,pmem,etime,comm --sort=-pcpu | __fzf \
        --label "Processes" \
        -- \
        --header-lines 1 \
        --preview 'ps -p {1} -o pid,ppid,user,stat,pcpu,pmem,etime,args --no-headers'
}

# fe - fuzzy environment variable search
function fe() {
    env | sort | __fzf \
        --label "Environment" \
        -- \
        --delimiter '=' \
        --with-nth '{1}' \
        --preview-window right:60%:noborder:wrap \
        --preview 'echo {2..} | tr : "\n"'
}

# fssh - fuzzy ssh host search
function fssh() {
    awk '/^Host / {for (i=2;i<=NF;i++) if ($i !~ /[*?]/) print $i}' ~/.ssh/config 2>/dev/null | \
        sort -u | __fzf \
        --label "SSH Hosts" \
        --no-multi \
        -- \
        --preview "awk -v h={1} '/^Host / {p=0; for (i=2;i<=NF;i++) if (\$i==h) p=1} p' ~/.ssh/config"
}

# fh - fuzzy history search
function fh() {
    # Reads $HISTFILE directly instead of `fc -l` — fc only sees the current
    # shell's in-memory history, which is empty in a non-interactive run.
    local histfile="${HISTFILE:-$HOME/.zsh_history}"
    # tac before dedup so the kept copy of a repeated command is its most
    # recent run, not its first-ever one.
    sed -E 's/^: [0-9]+:[0-9]+;//' "$histfile" | tac | awk '!seen[$0]++' | __fzf \
        --label "History" \
        --no-multi \
        -- \
        --scheme history
}
