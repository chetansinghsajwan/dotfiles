{
  description = "yazi, wrapped with its plugins, keymap, and theme baked in";

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
      forEachSystem =
        f:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ] f;

      # This repo's own yazi customization (plugins, keymap, settings, and
      # - when `colors` is passed - a Stylix-driven theme), baked in as the
      # default so a bare `mkYazi { inherit pkgs; }` already produces the
      # fully configured tool.
      mkYazi =
        {
          pkgs,
          # base16 palette as { base00 = "#hex"; ...; cyan = "#hex"; ... },
          # e.g. `config.lib.stylix.colors.withHashtag` from a home-manager
          # config. Left unthemed (yazi's own defaults) when null.
          colors ? null,
        }:
        wrappers.lib.evalPackage [
          { inherit pkgs; }
          wrappers.wrapperModules.yazi
          (import ./module.nix { inherit colors; })
        ];
    in
    {
      lib = { inherit mkYazi; };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkYazi { inherit pkgs; };
        }
      );
    };
}
