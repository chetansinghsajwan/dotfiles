# Builds one binary crate from the Cargo workspace in this directory.
{
    lib,
    rustPlatform,
    git,
}:
name:
rustPlatform.buildRustPackage {
    pname = name;
    version = "0.1.0";
    src = lib.cleanSourceWith {
        src = ./.;
        filter = path: _: baseNameOf path != "target";
    };
    cargoLock.lockFile = ./Cargo.lock;
    # git-core's tests build real repositories with the git CLI.
    nativeCheckInputs = [ git ];
    cargoBuildFlags = [
        "--package"
        name
    ];
    cargoTestFlags = [
        "--package"
        name
    ];
}
