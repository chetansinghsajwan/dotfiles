# Builds the whole Cargo workspace in this directory once and installs every
# binary (pv, pick, files, git-panel, ui-demo). One derivation, so a change to
# any crate costs one build, and the dependencies are cached apart from it.
# Tests run in the dev loop (`cargo test`), not here.
{
    lib,
    craneLib,
}:
let
    commonArgs = {
        pname = "crates";
        version = "0.1.0";
        src = lib.cleanSourceWith {
            src = ./.;
            filter = path: _: baseNameOf path != "target";
        };
        strictDeps = true;
        cargoExtraArgs = "--locked --workspace";
        doCheck = false;
    };
    cargoArtifacts = craneLib.buildDepsOnly commonArgs;
in
craneLib.buildPackage (commonArgs // { inherit cargoArtifacts; })
