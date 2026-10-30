{ pkgs, crane, ... }:
{
    # Our Rust tools, built together from home/crates: `pv` (preview), `pick`
    # (picker), `files` (explorer), `git-panel`, `ui-demo`.
    home.packages = [ (pkgs.callPackage ../crates { craneLib = crane.mkLib pkgs; }) ];
}
