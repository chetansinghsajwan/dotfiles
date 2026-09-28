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

      # The complete tealdeer wrapper (nix-wrapper-modules' own native
      # tealdeer module plus this repo's customization - see
      # modules/module.nix), shared between the home-manager module
      # below and a bare package build.
      wrapperModule = ./modules/module.nix;

      # Builds the same wrapped tealdeer both `lib.mkTealdeer` (for
      # external callers) and `packages.default` (this flake's own
      # standalone build) use, so there's exactly one module list to
      # keep in sync instead of two.
      mkTealdeer =
        { pkgs }:
        wrappers.lib.evalPackage [
          { inherit pkgs; }
          wrapperModule
        ];
    in
    {
      lib = {
        inherit mkTealdeer;
      };

      # Drop-in home-manager module: `imports = [ tealdeer-wrapped.homeModules.default ];`
      # wires everything up; the caller still sets
      # `wrappers.tealdeer.enable = true;` to actually turn it on.
      homeModules.default = {
        imports = [
          (wrappers.lib.getInstallModule {
            name = "tealdeer";
            value = wrapperModule;
          })
        ];
      };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkTealdeer { inherit pkgs; };
        }
      );
    };
}
