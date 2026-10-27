{ pkgs, ... }:
{
    # `pv` (preview): Rust, from home/crates/pv. Syntax-highlighted text and
    # compact directory trees, colored from the shared `ui` tokens. Installed as
    # a plain PATH binary so yazi's `piper` (bare `sh -c`) can call it; piper
    # sets $w/$h to the pane size, which pv reads.
    home.packages = [ (pkgs.callPackage ../../crates { } "pv") ];
}
