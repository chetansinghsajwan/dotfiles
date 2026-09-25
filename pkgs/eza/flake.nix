{
  description = "eza, wrapped with its flags baked in";

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

      wrapperModule = ./module.nix;
    in
    {
      lib = {
        mkEza =
          { pkgs }:
          wrappers.lib.evalPackage [
            { inherit pkgs; }
            wrapperModule
          ];
      };

      # Drop-in home-manager module: `imports = [ eza-wrapped.homeModules.default ];`
      # is the whole integration.
      homeModules.default = {
        imports = [
          (wrappers.lib.getInstallModule {
            name = "eza";
            value = wrapperModule;
          })
        ];

        # ls/ll/la/lt/lla all resolve "eza" through the alias chain to the
        # wrapped binary above, so --git/--icons apply to these too without
        # needing to repeat them here.
        config.home.shellAliases = {
          ls = "eza";
          ll = "eza -l";
          la = "eza -a";
          lt = "eza --tree";
          lla = "eza -la";
        };
      };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = wrappers.lib.evalPackage [
            { inherit pkgs; }
            wrapperModule
          ];
        }
      );
    };
}
