{
  description = "helix, wrapped with its config and theme baked in";

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

      # This repo's own helix customization, shared between the
      # home-manager module below and a bare package build. Doesn't
      # include theming or the editor.{scroll-lines,line-number,rulers,
      # text-width} settings sourced from config.dotfiles.editor: a plain
      # wrapper module only ever sees its own submodule config, not the
      # config of whatever imports it, so those have to come from the
      # caller.
      wrapperModule = ./module.nix;
    in
    {
      lib = {
        inherit mkTheme;

        mkHelix =
          {
            pkgs,
            # base16 palette as { base00 = "hex"; ...; base0F = "hex"; }
            # WITHOUT a leading "#" (e.g. `config.lib.stylix.colors`, not
            # `.withHashtag`). Left unthemed (helix's own defaults) when null.
            colors ? null,
          }:
          wrappers.lib.evalPackage [
            { inherit pkgs; }
            wrappers.wrapperModules.helix
            wrapperModule
            (mkTheme colors)
          ];
      };

      # Drop-in home-manager module: `imports = [ helix-wrapped.homeModules.default ];`
      # is the whole integration - no settings or packages needed at the
      # call site. Themes itself from Stylix when present, sizes itself
      # from config.dotfiles.editor, and sets EDITOR/VISUAL (was
      # programs.helix.defaultEditor).
      homeModules.default =
        {
          config,
          lib,
          ...
        }:
        let
          editor = config.dotfiles.editor;
        in
        {
          imports = [
            (wrappers.lib.getInstallModule {
              name = "helix";
              value = [
                wrappers.wrapperModules.helix
                wrapperModule
              ];
            })
          ];

          config.wrappers.helix =
            lib.recursiveUpdate
              (mkTheme (
                lib.attrByPath [
                  "lib"
                  "stylix"
                  "colors"
                ] null config
              ))
              {
                settings.editor = {
                  scroll-lines = editor.scroll_lines;
                  line-number = editor.line_number;
                  inherit (editor) rulers;
                  text-width = editor.text_width;
                };
              };

          config.home.sessionVariables = {
            EDITOR = "hx";
            VISUAL = "hx";
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
            wrappers.wrapperModules.helix
            wrapperModule
          ];
        }
      );
    };
}
