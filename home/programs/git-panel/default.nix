{ pkgs, crane, ... }:
{
    # `git-panel`: the shared git status panel (Rust, home/crates/git-panel):
    # changed files by section, the diff, stage / unstage / discard / commit.
    # Enter prints the file's path. Inside zellij it opens as a popup.
    home.packages = [ (pkgs.callPackage ../../crates { craneLib = crane.mkLib pkgs; } "git-panel") ];
}
