{
  description = "tealdeer, wrapped with its config baked in";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    wrappers = {
      url = "github:nix-community/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, wrappers, ... }:
    let
      inherit (nixpkgs) lib;

      forEachSystem =
        f:
        lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ] f;

      # This repo's own tealdeer customization, shared between the
      # home-manager module below and a bare package build.
      wrapperModule = ./module.nix;
    in
    {
      lib = {
        mkTealdeer =
          { pkgs }:
          wrappers.lib.evalPackage [
            { inherit pkgs; }
            wrappers.wrapperModules.tealdeer
            wrapperModule
          ];
      };

      # Drop-in home-manager module: `imports = [ tealdeer-wrapped.homeModules.default ];`
      # wires everything up; the caller still sets
      # `wrappers.tealdeer.enable = true;` to actually turn it on.
      homeModules.default = {
        imports = [
          (wrappers.lib.getInstallModule {
            name = "tealdeer";
            value = [
              wrappers.wrapperModules.tealdeer
              wrapperModule
            ];
          })
        ];
      };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = wrappers.lib.evalPackage [
            { inherit pkgs; }
            wrappers.wrapperModules.tealdeer
            wrapperModule
          ];
        }
      );
    };
}
