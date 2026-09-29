{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, ... }:
  let
    llib = import ../../lib { lib = nixpkgs.lib; };
    yazi = import ./yazi.nix;
  in
  {
    lib = {
      mkYazi = yazi.mkYazi;
    };

    packages = llib.forEachSystem (s: {
      default = yazi.mkYazi { pkgs = nixpkgs.legacyPackages.${s}; };
    });
  };
}
