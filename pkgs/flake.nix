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
        # helix-improved depends on tuikit as a git dependency (so it builds on its own). Here it is
        # built against the tuikit checked out next to it: the crates are copied into the source and
        # a cargo `[patch]` points the git dependency at them. The lockfile still names the git
        # revision, so the build runs without `--locked` and cargo re-resolves the patched crates.
        tuikitCrates = ["diagnostics-panel" "files" "git-core" "git-panel" "pick" "pv" "symbols-panel" "tb" "ui"];
        helixSrc = pkgs:
            pkgs.runCommand "helix-improved-src" {} ''
                cp -r ${helix-improved.lib.sourceOf pkgs.lib} $out
                chmod -R u+w $out
                mkdir $out/tuikit
                cp -r ${tuikit}/Cargo.toml ${tuikit}/crates $out/tuikit/
                cat >> $out/.cargo/config.toml <<'EOF'

                [patch."https://github.com/chetansinghsajwan/tuikit"]
                ${nixpkgs.lib.concatMapStringsSep "\n" (c: "tuikit-${c} = { path = \"tuikit/crates/${c}\" }") tuikitCrates}
                EOF
            '';
    in {
        packages = llib.forEachSystem (
            sys:
                tuikit.packages.${sys}
                // {
                    helix = helix-improved.lib.helixFrom nixpkgs.legacyPackages.${sys} (helixSrc nixpkgs.legacyPackages.${sys});
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
