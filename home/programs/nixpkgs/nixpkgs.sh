# Fuzzy nixpkgs pickers on `pick` (the shared picker, from the pickers module).
#
# `nix search` evaluates nixpkgs and is too slow (seconds, even warm cache)
# to reload on every keystroke like fs's live ripgrep search does, so these
# are two-step: run one search/query up front, then browse the results with
# pick's own (instant, local) fuzzy matching instead of reloading.

# fnp - fuzzy nixpkgs package search; prints the attribute name, and ctrl-e
# opens a `nix shell` with the package instead.
function fnp() {
    if [[ $# -eq 0 ]]; then
        printf "Search nixpkgs: " >&2
        local q
        read -r q
        [[ -z $q ]] && return 1
        set -- "$q"
    fi
    local query="$*"

    local json_file tsv_file
    json_file=$(mktemp)
    tsv_file=$(mktemp)

    echo "Searching nixpkgs for '$query'..." >&2
    # Positional args are ANDed by `nix search`, so `fnp foo bar` narrows
    # rather than searching the literal string "foo bar".
    if ! nix search nixpkgs "$@" --json >"$json_file" 2>/dev/null; then
        echo "nix search failed" >&2
        rm -f "$json_file" "$tsv_file"
        return 1
    fi

    # Attr keys come back as "legacyPackages.<system>.<attr>"; strip that
    # prefix since the system is constant and just clutters the list.
    jq -r 'to_entries[] | [(.key | sub("^legacyPackages\\.[^.]+\\.";"")), .value.version, .value.description] | @tsv' \
        "$json_file" >"$tsv_file"

    if [[ ! -s $tsv_file ]]; then
        echo "No packages found for '$query'" >&2
        rm -f "$json_file" "$tsv_file"
        return 1
    fi

    local preview="awk -F'\\t' -v a={1} '\$1==a{print \$1\" \"\$2; print \"\"; print \$3}' '$tsv_file'"
    local out key attr
    out=$(column -t -s $'\t' "$tsv_file" | pick \
        --title "Nix Packages: $query" \
        --expect ctrl-e \
        --preview-cmd "$preview")
    rm -f "$json_file" "$tsv_file"

    key=$(sed -n 1p <<<"$out")
    attr=$(sed -n 2p <<<"$out" | awk '{print $1}')
    [[ -z $attr ]] && return 0

    if [[ $key == ctrl-e ]]; then
        nix shell "nixpkgs#$attr"
    else
        echo "$attr"
    fi
}

# fnpi - fuzzy search packages actually installed in this home-manager profile
function fnpi() {
    local profile
    profile="/etc/profiles/per-user/$(whoami)"
    [[ -d $profile ]] || profile="$HOME/.nix-profile"

    # home-manager profiles reference one intermediate "home-manager-path"
    # derivation rather than the packages directly; unwrap it when present,
    # otherwise (plain nix profile) query the profile itself.
    local pkg_root
    pkg_root=$(nix-store -q --references "$profile" 2>/dev/null | grep -- '-home-manager-path$')
    [[ -z $pkg_root ]] && pkg_root="$profile"

    # Lines are "name<TAB>store path": only the name is shown and printed, the
    # path feeds the preview.
    nix-store -q --references "$pkg_root" 2>/dev/null |
        sed -E 's|^(/nix/store/[a-z0-9]{32}-)(.*)$|\2\t\1\2|' |
        sort |
        pick --title "Installed Packages" \
            --delimiter $'\t' \
            --with-nth 1 \
            --preview-cmd 'eza -lah --color=always --icons=always {2}' |
        cut -f1
}
