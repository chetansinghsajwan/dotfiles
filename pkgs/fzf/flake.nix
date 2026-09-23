{
  description = "fzf, wrapped with its default options and theme baked in";

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

      # Base16 -> fzf --color mapping, taken from tinted-theming/base16-fzf's
      # templates/default.mustache (the same template Stylix's own fzf
      # target renders through).
      mkThemeColors = colors: {
        bg = colors.base00;
        "bg+" = colors.base01;
        fg = colors.base04;
        "fg+" = colors.base06;
        header = colors.base0D;
        hl = colors.base0D;
        "hl+" = colors.base0D;
        info = colors.base0A;
        marker = colors.base0C;
        pointer = colors.base0C;
        prompt = colors.base0A;
        spinner = colors.base0C;
      };

      mkFzf =
        {
          pkgs,
          lib ? pkgs.lib,
          # Raw --flag strings, applied before --color (e.g. "--layout reverse").
          extraOptions ? [ ],
          # Base16 palette as { base00 = "#hex"; ...; base0F = "#hex"; }
          # (Stylix's `config.lib.stylix.colors.withHashtag` shape). Omit
          # for an unthemed build.
          colors ? null,
          # Per-key overrides applied on top of the base16 mapping, e.g.
          # { bg = "-1"; "bg+" = "-1"; } to fall back to the terminal's
          # own background instead of a solid theme color.
          colorOverrides ? { },
        }:
        let
          themeColors = lib.optionalAttrs (colors != null) (mkThemeColors colors) // colorOverrides;

          colorArg =
            lib.optionalString (themeColors != { })
              "--color ${lib.concatStringsSep "," (lib.mapAttrsToList (k: v: "${k}:${v}") themeColors)}";

          optsString = lib.concatStringsSep " " (extraOptions ++ lib.optional (colorArg != "") colorArg);
        in
        pkgs.symlinkJoin {
          name = "fzf-wrapped";
          paths = [ pkgs.fzf ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/fzf --set FZF_DEFAULT_OPTS ${lib.escapeShellArg optsString}
          '';
        };
    in
    {
      lib = { inherit mkFzf; };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkFzf { inherit pkgs; };
        }
      );
    };
}
