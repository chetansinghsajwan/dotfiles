{
  description = "yazi, wrapped with its config, plugins, theme, and shell integration baked in";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      forEachSystem =
        f:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ] f;

      # Static base16 -> yazi theme mapping (see theme.toml), taken from
      # tinted-theming/base16-yazi's templates/default.mustache (the same
      # template Stylix's own yazi target renders through). Only the
      # @baseNN@/@syntectTheme@ placeholders are per-build - substituted
      # below from whatever base16 palette/syntect theme is passed to
      # mkYazi.
      themeTemplate = builtins.readFile ./theme.toml;

      mkThemeToml =
        colors: syntectTheme:
        builtins.replaceStrings
          ((map (name: "@${name}@") (builtins.attrNames colors)) ++ [ "@syntectTheme@" ])
          ((builtins.attrValues colors) ++ [ (if syntectTheme == null then "" else toString syntectTheme) ])
          themeTemplate;

      mkYazi =
        {
          pkgs,
          lib ? pkgs.lib,
          settings ? { },
          keymap ? { },
          # Path to a Lua file, written verbatim as init.lua.
          initLua ? null,
          # Plugins as { <name> = <path>; ... }, symlinked to
          # <config-dir>/plugins/<name>.yazi.
          plugins ? { },
          # Extra packages on PATH, on top of the previewer deps nixpkgs'
          # own pkgs.yazi wrapper bundles by default (see below).
          extraPackages ? [ ],
          # Base16 palette as { base00 = "#hex"; ...; base0F = "#hex"; }
          # (Stylix's `config.lib.stylix.colors.withHashtag` shape). Omit
          # for an unthemed build.
          colors ? null,
          # Path to a .tmTheme file for mgr.syntect_theme (text-preview
          # syntax highlighting). Only used when colors != null.
          syntectTheme ? null,
        }:
        let
          tomlFormat = pkgs.formats.toml { };

          configFile = tomlFormat.generate "yazi.toml" settings;
          keymapFile = tomlFormat.generate "keymap.toml" keymap;

          themeFile = pkgs.writeText "theme.toml" (mkThemeToml colors syntectTheme);

          configDir = pkgs.runCommand "yazi-config-dir" { } (
            ''
              mkdir -p $out/plugins
              ln -s ${configFile} $out/yazi.toml
              ln -s ${keymapFile} $out/keymap.toml
            ''
            + lib.optionalString (colors != null) ''
              ln -s ${themeFile} $out/theme.toml
            ''
            + lib.optionalString (initLua != null) ''
              ln -s ${pkgs.writeText "init.lua" (builtins.readFile initLua)} $out/init.lua
            ''
            + lib.concatStrings (
              lib.mapAttrsToList (name: path: ''
                ln -s ${path} $out/plugins/${name}.yazi
              '') plugins
            )
          );

          # Matches the previewer deps nixpkgs' own pkgs.yazi wrapper puts
          # on PATH (resvg/chafa/imagemagick for image previews, poppler
          # for PDF, jq for JSON, file for MIME sniffing, fd/rg/fzf/zoxide
          # for plugins that shell out to them, 7zz/ffmpeg for archive and
          # media metadata) - replicated here since this wraps
          # yazi-unwrapped instead.
          defaultExtraPackages = with pkgs; [
            resvg
            chafa
            imagemagick
            zoxide
            fzf
            ripgrep
            fd
            ffmpeg-headless
            _7zz
            poppler-utils
            jq
            file
          ];
        in
        pkgs.symlinkJoin {
          name = "yazi-wrapped";
          # Wrap yazi-unwrapped, not pkgs.yazi - see pkgs/helix/flake.nix
          # for why (avoids clobbering an existing wrapper's own flags).
          paths = [ pkgs.yazi-unwrapped ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/yazi \
              --set YAZI_CONFIG_HOME "${configDir}" \
              --suffix PATH : ${lib.makeBinPath (defaultExtraPackages ++ extraPackages)}

            # "y" cd-on-exit wrapper: opens yazi, then cds the calling shell
            # to wherever yazi was left in on exit.
            mkdir -p $out/share/yazi-shell
            cp ${./y.zsh} $out/share/yazi-shell/y.zsh
            cp ${./y.fish} $out/share/yazi-shell/y.fish
            cp ${./y.nu} $out/share/yazi-shell/y.nu
          '';
        };
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
