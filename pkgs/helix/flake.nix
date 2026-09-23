{
  description = "Helix editor, wrapped with its config and theme baked in";

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

      # Static base16 -> helix theme mapping (see theme.toml), taken from
      # tinted-theming/base16-helix's templates/base16.mustache (the same
      # template Stylix's own helix target renders through). Only the
      # [palette] table's @baseNN@ placeholders are per-scheme - substituted
      # below from whatever base16 palette is passed to mkHelix.
      themeTemplate = builtins.readFile ./theme.toml;

      mkThemeToml =
        colors:
        builtins.replaceStrings (map (name: "@${name}@") (
          builtins.attrNames colors
        )) (builtins.attrValues colors) themeTemplate;

      mkHelix =
        {
          pkgs,
          lib ? pkgs.lib,
          settings ? { },
          extraPackages ? [ ],
          # Base16 palette as { base00 = "#hex"; ...; base0F = "#hex"; }
          # (Stylix's `config.lib.stylix.colors.withHashtag` shape). Omit
          # for an unthemed build.
          colors ? null,
          # Strip the theme's background so a translucent terminal shows
          # through, same as Stylix's own helix target does when
          # opacity.terminal != 1.0.
          transparent ? false,
        }:
        let
          tomlFormat = pkgs.formats.toml { };

          configFile = tomlFormat.generate "config.toml" (
            settings // lib.optionalAttrs (colors != null) { theme = "stylix"; }
          );

          themeToml = pkgs.writeText "stylix.toml" (mkThemeToml colors);

          themeFinal =
            if transparent then
              pkgs.runCommand "stylix-transparent.toml" { } ''
                sed 's/,\? bg = "base00"//g' ${themeToml} > $out
              ''
            else
              themeToml;

          # helix's own runtime dir (grammars/queries) has no themes/ by
          # default - built-in themes are compiled in. Merge our theme file
          # alongside it so a custom `theme = "stylix"` resolves.
          runtimeDir = pkgs.symlinkJoin {
            name = "helix-runtime-themed";
            paths = [ pkgs.helix.passthru.runtime ];
            postBuild = lib.optionalString (colors != null) ''
              mkdir -p $out/themes
              cp ${themeFinal} $out/themes/stylix.toml
            '';
          };
        in
        pkgs.symlinkJoin {
          name = "helix-wrapped";
          # Wrap helix-unwrapped (the raw binary), not pkgs.helix - that's
          # already wrapped with its own unconditional
          # `--set HELIX_RUNTIME`, which would clobber ours.
          paths = [ pkgs.helix-unwrapped ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/hx \
              --set HELIX_RUNTIME "${runtimeDir}" \
              --add-flags "--config ${configFile}" \
              --suffix PATH : ${lib.makeBinPath extraPackages}

            ln -s ${pkgs.helix-unwrapped}/bin/hx $out/bin/hx-unwrapped
          '';
        };
    in
    {
      lib = { inherit mkHelix; };

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
