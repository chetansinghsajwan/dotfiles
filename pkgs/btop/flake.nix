{
  description = "btop, wrapped with its config and theme baked in";

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

      # Static base16 -> btop theme mapping (see theme.theme), taken from
      # tinted-theming/base16-btop's templates/default.mustache (the same
      # template Stylix's own btop target renders through). Only the
      # @baseNN@ placeholders are per-scheme - substituted below from
      # whatever base16 palette is passed to mkBtop.
      themeTemplate = builtins.readFile ./theme.theme;

      # btop's own config format: flat "key = value" lines, booleans spelled
      # "True"/"False" and strings double-quoted - not a format
      # pkgs.formats.* already speaks, so rendered by hand here.
      renderValue =
        v:
        if builtins.isBool v then
          (if v then "True" else "False")
        else if builtins.isString v then
          builtins.toJSON v
        else
          toString v;

      mkConfigText =
        settings:
        builtins.concatStringsSep "\n" (
          builtins.attrValues (builtins.mapAttrs (name: value: "${name} = ${renderValue value}") settings)
        );

      mkBtop =
        {
          pkgs,
          lib ? pkgs.lib,
          settings ? { },
          extraPackages ? [ ],
          # Base16 palette as { base00 = "#hex"; ...; base0F = "#hex"; }
          # (Stylix's `config.lib.stylix.colors.withHashtag` shape). Omit
          # for an unthemed build.
          colors ? null,
          # localLib.wrapped.base16.substituteTemplate - see
          # pkgs/helix/flake.nix for why this is a parameter and not a
          # local definition.
          substituteTemplate ? (
            template: replacements:
            builtins.replaceStrings (map (name: "@${name}@") (
              builtins.attrNames replacements
            )) (builtins.attrValues replacements) template
          ),
        }:
        let
          configFile = pkgs.writeText "btop.conf" (
            mkConfigText (settings // lib.optionalAttrs (colors != null) { color_theme = "stylix"; })
          );

          themesDir = pkgs.runCommand "btop-themes" { } (
            ''
              mkdir -p $out
            ''
            + lib.optionalString (colors != null) ''
              cp ${pkgs.writeText "stylix.theme" (substituteTemplate themeTemplate colors)} $out/stylix.theme
            ''
          );
        in
        pkgs.symlinkJoin {
          name = "btop-wrapped";
          paths = [ pkgs.btop ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/btop \
              --add-flags "--config ${configFile} --themes-dir ${themesDir}" \
              --suffix PATH : ${lib.makeBinPath extraPackages}
          '';
        };
    in
    {
      lib = { inherit mkBtop; };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkBtop { inherit pkgs; };
        }
      );
    };
}
