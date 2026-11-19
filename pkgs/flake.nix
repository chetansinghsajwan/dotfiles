# Our Rust code in this repo: kb (pkgs/kb) and, from two submodules, the tuikit tools and the
# helix-improved editor.
# Re-exported here so home takes every package from one place. Locking happens in the repo root
# flake.lock; this flake has no lock of its own.
{
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

        llib = {
            url = "path:../lib";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        # Splits cargo builds into a cached dependency build and our code.
        crane.url = "github:ipetkov/crane";

        tuikit = {
            url = "path:./tuikit";
            inputs.nixpkgs.follows = "nixpkgs";
            inputs.crane.follows = "crane";
        };

        helix-improved = {
            url = "path:./helix-improved";
            inputs.nixpkgs.follows = "nixpkgs";
            inputs.crane.follows = "crane";
        };
    };

    outputs = {
        nixpkgs,
        llib,
        tuikit,
        helix-improved,
        ...
    }: let
        # The tuikit tree copied to a store path of its own, so the helix build depends on tuikit alone and
        # not on the whole dotfiles source it sits in (any commit would otherwise change the helix hash and
        # miss the binary cache). Never local build output (target/).
        tuikitSrc = builtins.path {
            path = tuikit.outPath;
            name = "tuikit-source";
            filter = path: _: baseNameOf path != "target";
        };
    in {
        packages = llib.forEachSystem (
            sys:
                tuikit.packages.${sys}
                // {
                    # helix-improved takes tuikit as a git dependency; here it is built against the tuikit checked
                    # out next to it (a cargo `[patch]` added during the build), so both come from one tree.
                    helix = helix-improved.lib.helixFrom nixpkgs.legacyPackages.${sys} {inherit tuikitSrc;};
                }
                // {
                    kb = nixpkgs.legacyPackages.${sys}.rustPlatform.buildRustPackage {
                        pname = "kb";
                        version = "0.1.0";
                        src = ./kb;
                        cargoLock.lockFile = ./kb/Cargo.lock;
                        meta.mainProgram = "kb";
                    };
                }
        );
    };
}
