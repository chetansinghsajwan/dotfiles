{ pkgs, crane, ... }:
{
    # Our Rust tools, built together from home/crates: `pv` (preview), `pick`
    # (picker), `files` (explorer), `git-panel`, `git-ui` (the multi-pane git
    # screen), `ui-demo`.
    home.packages = [ (pkgs.callPackage ../crates { craneLib = crane.mkLib pkgs; }) ];

    # `gu`: the multi-pane git screen.
    home.shellAliases.gu = "git-ui";
}
