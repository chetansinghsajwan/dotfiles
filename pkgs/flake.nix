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

    outputs =
        {
            nixpkgs,
            llib,
            tuikit,
            helix-improved,
            ...
        }:
        {
            packages = llib.forEachSystem (
                sys:
                tuikit.packages.${sys}
                // {
                    inherit (helix-improved.packages.${sys}) helix;
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
