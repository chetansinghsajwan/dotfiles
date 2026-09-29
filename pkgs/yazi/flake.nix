{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    llib = {
      url = "path:../../lib";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, llib, ... }:
  let
    yazi = import ./yazi.nix { llib };
  in
  {
    lib = with yazi; {
      inherit mkYazi mkTheme;
    };

    packages = llib.forEachSystem (s: {
      default = yazi.mkYazi {
        pkgs = nixpkgs.legacyPackages.${s};
      };
    });
  };
}
