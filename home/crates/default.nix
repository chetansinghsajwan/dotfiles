# Builds one binary crate from the Cargo workspace in this directory.
# Dependencies are built once for the whole workspace and shared by every crate.
{
    lib,
    craneLib,
    git,
}:
name:
let
    commonArgs = {
        pname = "crates-deps";
        version = "0.1.0";
        src = lib.cleanSourceWith {
            src = ./.;
            filter = path: _: baseNameOf path != "target";
        };
        strictDeps = true;
        # git-core's tests build real repositories with the git CLI.
        nativeCheckInputs = [ git ];
    };
    cargoArtifacts = craneLib.buildDepsOnly commonArgs;
in
craneLib.buildPackage (
    commonArgs
    // {
        inherit cargoArtifacts;
        pname = name;
        cargoExtraArgs = "--package ${name}";
    }
)
