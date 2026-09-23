{
  description = "zellij, wrapped with its config and theme baked in";

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

      themeTemplate = builtins.readFile ./theme.kdl;

      mkThemeKdl =
        colors:
        builtins.replaceStrings (map (name: "@${name}@") (
          builtins.attrNames colors
        )) (builtins.attrValues colors) themeTemplate;

      mkZellij =
        {
          pkgs,
          lib ? pkgs.lib,
          # Raw KDL merged into config.kdl verbatim (keybinds, plugin
          # aliases, top-level options, ...).
          extraConfig ? "",
          # Named layouts as { <name> = "<kdl>"; ... }, written to
          # <config-dir>/layouts/<name>.kdl. A layout named "default"
          # overrides zellij's built-in default layout with no further
          # config needed.
          layouts ? { },
          # Base16 palette as { base00 = "#hex"; ...; base0F = "#hex"; }
          # (Stylix's `config.lib.stylix.colors.withHashtag` shape). Omit
          # for an unthemed build.
          colors ? null,
        }:
        let
          configFile = pkgs.writeText "config.kdl" extraConfig;

          # zellij resolves <config-dir>/themes and <config-dir>/layouts by
          # default, same as its normal XDG config dir - no theme_dir/
          # layout_dir directives needed in config.kdl.
          configDir = pkgs.runCommand "zellij-config-dir" { } (
            ''
              mkdir -p $out/layouts
            ''
            + lib.concatStrings (
              lib.mapAttrsToList (name: content: ''
                cp ${pkgs.writeText "${name}.kdl" content} $out/layouts/${name}.kdl
              '') layouts
            )
            + lib.optionalString (colors != null) ''
              mkdir -p $out/themes
              cp ${pkgs.writeText "stylix.kdl" (mkThemeKdl colors)} $out/themes/stylix.kdl
            ''
          );
        in
        pkgs.symlinkJoin {
          name = "zellij-wrapped";
          # Wrap zellij-unwrapped, not pkgs.zellij - see pkgs/helix/flake.nix
          # for why (avoids clobbering an existing wrapper's own flags).
          paths = [ pkgs.zellij-unwrapped ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/zellij \
              --add-flags "--config ${configFile} --config-dir ${configDir}"
          '';
        };
    in
    {
      lib = { inherit mkZellij; };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkZellij { inherit pkgs; };
        }
      );
    };
}
