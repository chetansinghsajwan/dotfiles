{
  description = "lazygit, wrapped with its config and theme baked in";

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

      mkTheme = import ./theme.nix;

      # nix-wrapper-modules doesn't ship a native lazygit wrapper module,
      # so wrapper-module.nix stands in for one (package + settings ->
      # config.yml). This repo's own lazygit customization, shared between
      # the home-manager module below and a bare package build. Doesn't
      # include theming: a plain wrapper module only ever sees its own
      # submodule config, not the config of whatever imports it, so theme
      # colors have to come from the caller.
      wrapperModule = ./module.nix;
      baseModule = ./wrapper-module.nix;
    in
    {
      lib = {
        inherit mkTheme;

        mkLazygit =
          {
            pkgs,
            # base16 palette as { base00 = "#hex"; ...; }, e.g.
            # `config.lib.stylix.colors.withHashtag`. Left unthemed (lazygit's
            # own defaults) when null.
            colors ? null,
          }:
          wrappers.lib.evalPackage [
            { inherit pkgs; }
            baseModule
            wrapperModule
            { config.settings = mkTheme colors; }
          ];
      };

      # Drop-in home-manager module: `imports = [ lazygit-wrapped.homeModules.default ];`
      # is the whole integration - no settings or packages needed at the
      # call site. Themes itself from Stylix when present.
      homeModules.default =
        {
          config,
          lib,
          ...
        }:
        {
          imports = [
            (wrappers.lib.getInstallModule {
              name = "lazygit";
              value = [
                baseModule
                wrapperModule
              ];
            })
          ];

          config.wrappers.lazygit.settings = mkTheme (
            lib.attrByPath [
              "lib"
              "stylix"
              "colors"
              "withHashtag"
            ] null config
          );
        };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = wrappers.lib.evalPackage [
            { inherit pkgs; }
            baseModule
            wrapperModule
          ];
        }
      );
    };
}
