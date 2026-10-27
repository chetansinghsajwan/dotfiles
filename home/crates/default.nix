# Builds one binary crate from the Cargo workspace in this directory.
{ lib, rustPlatform }:
name:
rustPlatform.buildRustPackage {
    pname = name;
    version = "0.1.0";
    src = lib.cleanSourceWith {
        src = ./.;
        filter = path: _: baseNameOf path != "target";
    };
    cargoLock.lockFile = ./Cargo.lock;
    cargoBuildFlags = [
        "--package"
        name
    ];
    cargoTestFlags = [
        "--package"
        name
    ];
}
