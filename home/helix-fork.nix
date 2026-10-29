# Our helix fork (home/helix) with the shared crates (home/crates).
#
# The unwrapped editor is built here. The runtime directory (queries plus the
# tree-sitter grammars built by Nix) comes from nixpkgs' own `helix` wrapper,
# which we reuse by swapping in our unwrapped build. That is valid because the
# fork is based on the same upstream tag nixpkgs ships (see home/helix/FORK.md);
# when nixpkgs moves to another helix version, rebase the fork first.
{
    lib,
    craneLib,
    runCommand,
    helix,
    helix-unwrapped,
}:
let
    # Layout `source/{helix,crates}`: helix-term has path dependencies on
    # `../../crates/{pick,ui}` that must resolve inside the build directory.
    src = lib.fileset.toSource {
        root = ./.;
        # Without local build output (target/), so the result does not depend on it.
        fileset =
            lib.fileset.difference
                (lib.fileset.unions [
                    ./helix
                    ./crates
                ])
                (
                    lib.fileset.unions [
                        (lib.fileset.maybeMissing ./crates/target)
                        (lib.fileset.maybeMissing ./helix/target)
                    ]
                );
    };
    helixSrc = "${src}/helix";

    # What helix falls back to when HELIX_RUNTIME is unset: themes, languages
    # and so on, without the queries and grammars that the wrapper supplies.
    defaultRuntimeDir = runCommand "helix-fork-default-runtime" { } ''
        cp -r --no-preserve=mode ${helixSrc}/runtime $out
        rm -rf $out/grammars $out/queries
    '';

    commonArgs = {
        pname = "helix-unwrapped";
        inherit (helix-unwrapped) version;
        inherit src;
        # The workspace is in a subdirectory, next to the shared `crates`.
        postUnpack = "cd $sourceRoot/helix; sourceRoot=.";
        cargoLock = ./helix/Cargo.lock;
        strictDeps = true;

        # Only the editor binary. The workspace's own tests are upstream's and
        # slow; `pick`, `pv`, `git-core` and `ui` are tested in home/crates.
        cargoExtraArgs = "--package helix-term";
        doCheck = false;

        env = {
            # Grammars are built by Nix, not by helix-term's build.rs.
            HELIX_DISABLE_AUTO_GRAMMAR_BUILD = "1";
            # A faster-to-build release: no LTO and parallel codegen cost a few
            # percent of runtime speed. Part of the shared args, so the
            # dependency build below stays valid for it.
            CARGO_PROFILE_RELEASE_LTO = "off";
            CARGO_PROFILE_RELEASE_CODEGEN_UNITS = "16";
            CARGO_PROFILE_RELEASE_DEBUG = "0";
        };
    };

    # All dependencies, built once from the manifests alone: editing our own
    # code (helix, crates) does not rebuild them.
    cargoArtifacts = craneLib.buildDepsOnly commonArgs;

    unwrapped = craneLib.buildPackage (
        commonArgs
        // {
            inherit cargoArtifacts;
            env = commonArgs.env // {
                HELIX_DEFAULT_RUNTIME = defaultRuntimeDir;
            };
            meta = helix-unwrapped.meta // {
                description = "Helix with the shared pick picker";
            };
        }
    );
in
# The wrapper reads `helix-unwrapped.src` for runtime/queries.
helix.override {
    helix-unwrapped = unwrapped // {
        src = helixSrc;
    };
}
