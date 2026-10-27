{ pkgs, ... }:
{
    # `pick`: the shared fuzzy picker (Rust, home/crates/pick). Candidates from
    # stdin or `--files`, preview through the `pv` library, selection on stdout.
    home.packages = [ (pkgs.callPackage ../../crates { } "pick") ];
}
