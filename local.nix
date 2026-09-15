# Machine-local config overrides. This file is tracked as an empty
# placeholder, then marked skip-worktree so real edits never show up in
# `git status`/`git diff` and can't be swept up by `git add -A`.
#
# One-time setup after cloning:
#   git update-index --skip-worktree local.nix
#
# Then edit freely — Nix reads this file's live on-disk content on every
# rebuild (no --impure needed), while git treats it as untouched.
#
# Return a plain module attrset, e.g.:
#   { dotfiles.theme.wallpaper = "/home/you/pictures/mine.png"; }
#
# Some options are already set with a plain assignment in a host's
# system.nix/default.nix (see hosts/*/). To win over those here, wrap the
# value in `lib.mkForce` (this file's `lib` arg is nixpkgs.lib):
#   { lib, ... }: { dotfiles.desktop.hyprland.shell = lib.mkForce "custom"; }
{ }
