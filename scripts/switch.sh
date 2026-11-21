#!/usr/bin/env bash
# Builds this flake for the current machine and switches to it, pulling the tuikit tools and the
# helix fork from the binary cache (the flake's nixConfig) instead of compiling them.
#
# It works on a machine that has nothing set up yet: the cache is enabled for this one run through
# NIX_CONFIG, so the first switch needs no flag and no prior config, and the switch command itself
# (nixos-rebuild, darwin-rebuild, home-manager) is fetched when the machine does not have it.
# The only prompt is sudo's password, because a system switch needs root.
#
# Usage: scripts/switch.sh [host]
#   host  an attribute under the configurations of this platform, for example `jman-nixos` or
#         `x86_64-linux.wsl`. Without it the host is the one named like this machine, else the
#         platform's default (`<system>.default`, `<system>.wsl` on WSL).
set -euo pipefail

# The repo root, so the script works from any directory.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Prints a message to stderr.
say() {
    printf 'switch: %s\n' "$*" >&2
}

# Prints the Nix system of this machine, such as x86_64-linux or aarch64-darwin.
nix_system() {
    local arch os
    arch="$(uname -m)"
    os="$(uname -s)"
    [ "$arch" = arm64 ] && arch=aarch64
    case "$os" in
    Darwin) echo "${arch}-darwin" ;;
    *) echo "${arch}-linux" ;;
    esac
}

# Prints the platform kind: darwin, nixos, or home (Linux without NixOS, standalone Home Manager).
platform_kind() {
    if [ "$(uname -s)" = Darwin ]; then
        echo darwin
    elif [ -e /etc/NIXOS ]; then
        echo nixos
    else
        echo home
    fi
}

# Fills the submodules (the flake sets `self.submodules`, and the tools and the editor live there).
ensure_submodules() {
    if [ -e "$root/.git" ] && [ -z "$(ls -A "$root/pkgs/tuikit" 2>/dev/null)" ]; then
        say "fetching the submodules"
        git -C "$root" submodule update --init --recursive
    fi
}

# Prints the host attribute to switch to. $1 is the platform kind, $2 the optional host argument.
pick_host() {
    local kind="$1" given="${2:-}" system names host err
    system="$(nix_system)"
    if [ -n "$given" ]; then
        echo "$given"
        return
    fi
    if [ "$kind" != home ]; then
        # A host named like this machine wins: jman-nixos, macbook-air13.
        # A plain user cannot apply the flake's cache settings, so Nix warns on every call here. The
        # warning is harmless for reading names, so stderr is shown only when the call fails.
        err="$(mktemp)"
        if ! names="$(nix eval --json "$root#${kind}Configurations" --apply builtins.attrNames 2>"$err")"; then
            cat "$err" >&2
            rm -f "$err"
            return 1
        fi
        rm -f "$err"
        for host in "$(hostname -s)" "$(scutil --get LocalHostName 2>/dev/null || true)"; do
            if [ -n "$host" ] && grep -q "\"$host\"" <<<"$names"; then
                echo "$host"
                return
            fi
        done
    fi
    if [ "$kind" = nixos ] && grep -qi microsoft /proc/version 2>/dev/null; then
        echo "${system}.wsl"
    else
        echo "${system}.default"
    fi
}

# Warns when the cache cannot be used: only root and trusted users may add a substituter, so a
# standalone Home Manager run by a plain user quietly falls back to compiling.
warn_if_untrusted() {
    local trusted
    trusted="$(nix config show trusted-users 2>/dev/null || true)"
    if [ "$(id -u)" != 0 ] && ! grep -qE "(^| )(\*|$USER)( |$)" <<<"$trusted"; then
        say "$USER is not a trusted Nix user, so the cache is ignored and the tools are compiled"
        say "to fix it, add \`trusted-users = $USER\` to /etc/nix/nix.conf and restart the Nix daemon"
    fi
}

# Switches a NixOS machine. The switch needs root, which also lets it use the cache.
switch_nixos() {
    sudo env NIX_CONFIG="$NIX_CONFIG" nixos-rebuild switch --flake "$root#$1"
}

# Switches a nix-darwin machine. The first run has no darwin-rebuild yet, so it is fetched.
switch_darwin() {
    local nix
    nix="$(command -v nix)"
    if command -v darwin-rebuild >/dev/null 2>&1; then
        sudo env NIX_CONFIG="$NIX_CONFIG" darwin-rebuild switch --flake "$root#$1"
    else
        sudo env NIX_CONFIG="$NIX_CONFIG" "$nix" run nix-darwin/master#darwin-rebuild -- \
            switch --flake "$root#$1"
    fi
}

# Switches a standalone Home Manager setup. The first run has no home-manager yet, so the one
# pinned by this flake is run. Files that are in the way are moved aside instead of prompting.
switch_home() {
    warn_if_untrusted
    if command -v home-manager >/dev/null 2>&1; then
        home-manager switch -b backup --flake "$root#$1"
    else
        nix run --inputs-from "$root" home-manager -- switch -b backup --flake "$root#$1"
    fi
}

# Runs the switch for this machine.
main() {
    local kind host
    kind="$(platform_kind)"

    # The cache applies to this run only: nothing is written to the Nix config, and the flake's
    # nixConfig (the cache URL and key) stays the single place that names the cache.
    export NIX_CONFIG="experimental-features = nix-command flakes
accept-flake-config = true"

    ensure_submodules
    host="$(pick_host "$kind" "${1:-}")"
    if [ "$kind" = home ]; then
        say "home-manager switch for ${host}"
    else
        say "${kind} switch for ${host}"
    fi
    case "$kind" in
    nixos) switch_nixos "$host" ;;
    darwin) switch_darwin "$host" ;;
    home) switch_home "$host" ;;
    esac
}

main "$@"
