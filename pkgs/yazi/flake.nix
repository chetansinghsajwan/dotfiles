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

      # This repo's own yazi customization (plugins, keymap, settings),
      # shared between the home-manager module below and a bare package
      # build. Doesn't include theming: a plain wrapper module only ever
      # sees its own submodule config, not the config of whatever imports
      # it, so theme colors have to come from the caller.
      wrapperModule = ./module.nix;
    in
    {
      lib = {
        inherit mkTheme;

        mkYazi =
          {
            pkgs,
            # base16 palette as { base00 = "#hex"; ...; cyan = "#hex"; ... },
            # e.g. `config.lib.stylix.colors.withHashtag`. Left unthemed
            # (yazi's own defaults) when null.
            colors ? null,
          }:
          wrappers.lib.evalPackage [
            { inherit pkgs; }
            wrappers.wrapperModules.yazi
            wrapperModule
            { config.settings.theme = mkTheme colors; }
          ];
      };

      # Drop-in home-manager module: `imports = [ yazi-wrapped.homeModules.default ];`
      # is the whole integration - no settings, packages, or shell wiring
      # needed at the call site. Themes itself from Stylix when present,
      # and wires the `y` (cd-on-quit) shell function into whichever of
      # zsh/fish/nushell is enabled.
      homeModules.default =
        {
          config,
          lib,
          ...
        }:
        {
          imports = [
            (wrappers.lib.getInstallModule {
              name = "yazi";
              value = [
                wrappers.wrapperModules.yazi
                wrapperModule
              ];
            })
          ];

          config.wrappers.yazi.settings.theme = mkTheme (
            lib.attrByPath [
              "lib"
              "stylix"
              "colors"
              "withHashtag"
            ] null config
          );

          config.home.file = {
            ".config/yazi/y.zsh" = lib.mkIf config.programs.zsh.enable { source = ./y.zsh; };
            ".config/yazi/y.fish" = lib.mkIf config.programs.fish.enable { source = ./y.fish; };
            ".config/yazi/y.nu" = lib.mkIf config.programs.nushell.enable { source = ./y.nu; };
          };

          config.wrappers.zsh.extraInitContent = lib.mkIf config.programs.zsh.enable ''
            source ~/.config/yazi/y.zsh
          '';

          config.programs.fish.interactiveShellInit = lib.mkIf config.programs.fish.enable ''
            source ~/.config/yazi/y.fish
          '';

          config.programs.nushell.extraConfig = lib.mkIf config.programs.nushell.enable (
            builtins.readFile ./y.nu
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
            wrappers.wrapperModules.yazi
            wrapperModule
          ];
        }
      );
    };
}
