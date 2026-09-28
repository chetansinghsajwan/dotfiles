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

      # The complete helix wrapper (nix-wrapper-modules' own native helix
      # module plus this repo's customization, including its own default
      # theme and editor sizing - see modules/module.nix), shared between
      # the home-manager module below and a bare package build. Themed
      # out of the box even with no caller-supplied `colors` at all - see
      # modules/module.nix's default (config.dotfiles.theme.colors).
      wrapperModule = ./modules/module.nix;

      # Builds the same wrapped helix both `lib.mkHelix` (for external
      # callers) and `packages.default` (this flake's own standalone
      # build) use, so there's exactly one module list to keep in sync
      # instead of two.
      mkHelix =
        {
          pkgs,
          # base16 palette as { base00 = "#hex"; ...; base0F = "#hex"; },
          # e.g. `config.lib.stylix.colors.withHashtag`. Overrides
          # module.nix's own default palette when given; left alone
          # (module.nix's default applies) when null.
          colors ? null,
        }:
        wrappers.lib.evalPackage (
          [
            { inherit pkgs; }
            wrapperModule
          ]
          ++ lib.optional (colors != null) { config.colors = colors; }
        );
    in
    {
      lib = {
        inherit mkHelix;
      };

      # Drop-in home-manager module: `imports = [ helix-wrapped.homeModules.default ];`
      # is the whole integration - no settings or packages needed at the
      # call site. Themes and sizes itself from Stylix/config.dotfiles.editor
      # when present, and sets EDITOR/VISUAL (was programs.helix.defaultEditor).
      homeModules.default =
        { config, lib, ... }:
        {
          imports = [
            (wrappers.lib.getInstallModule {
              name = "helix";
              value = wrapperModule;
            })
          ];

          # Only overrides module.nix's own default palette when Stylix is
          # actually present - otherwise leaves that default in place
          # rather than forcing colors to null.
          config.wrappers.helix.colors = lib.mkIf (lib.hasAttrByPath [
            "lib"
            "stylix"
            "colors"
            "withHashtag"
          ] config) config.lib.stylix.colors.withHashtag;

          # module.nix's own scrollLines/lineNumber/rulers/textWidth
          # defaults are read from a standalone, isolated evaluation of
          # config/default.nix alone - they never see this host's real
          # dotfiles.editor.* overrides (should any host ever set one in
          # hosts/*/default.nix), so they're explicitly recomputed here
          # from the live values and pushed in, the same way `colors` is
          # overridden above.
          config.wrappers.helix.scrollLines = config.dotfiles.editor.scroll_lines;
          config.wrappers.helix.lineNumber = config.dotfiles.editor.line_number;
          config.wrappers.helix.rulers = config.dotfiles.editor.rulers;
          config.wrappers.helix.textWidth = config.dotfiles.editor.text_width;

          # config.home.* is home-manager-only, so it can't move into
          # module.nix the way the theme/editor-size settings did.
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
          default = mkHelix { inherit pkgs; };
        }
      );
    };
}
