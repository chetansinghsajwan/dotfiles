{
  description = "lazygit, wrapped with its config and theme baked in";

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

      # Base16 -> lazygit gui.theme mapping, taken from
      # tinted-theming/base16-lazygit's templates/default.mustache (the
      # same template Stylix's own lazygit target renders through).
      mkTheme = colors: {
        activeBorderColor = [
          colors.base0D
          "bold"
        ];
        cherryPickedCommitBgColor = [ colors.base02 ];
        cherryPickedCommitFgColor = [ colors.base03 ];
        defaultFgColor = [ colors.base05 ];
        inactiveBorderColor = [ colors.base03 ];
        optionsTextColor = [ colors.base06 ];
        searchingActiveBorderColor = [
          colors.base04
          "bold"
        ];
        selectedLineBgColor = [ colors.base03 ];
        unstagedChangesColor = [ colors.base08 ];
      };

      mkLazygit =
        {
          pkgs,
          lib ? pkgs.lib,
          settings ? { },
          extraPackages ? [ ],
          # Base16 palette as { base00 = "#hex"; ...; base0F = "#hex"; }
          # (Stylix's `config.lib.stylix.colors.withHashtag` shape). Omit
          # for an unthemed build.
          colors ? null,
        }:
        let
          yamlFormat = pkgs.formats.yaml { };

          configFile = yamlFormat.generate "config.yml" (
            lib.recursiveUpdate settings (lib.optionalAttrs (colors != null) { gui.theme = mkTheme colors; })
          );
        in
        pkgs.symlinkJoin {
          name = "lazygit-wrapped";
          paths = [ pkgs.lazygit ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/lazygit \
              --add-flags "--use-config-file ${configFile}" \
              --suffix PATH : ${lib.makeBinPath extraPackages}
          '';
        };
    in
    {
      lib = { inherit mkLazygit; };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkLazygit { inherit pkgs; };
        }
      );
    };
}
