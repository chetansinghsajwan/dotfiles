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

      mkZellij =
        {
          pkgs,
          lib ? pkgs.lib,
          # config.kdl's content as a list of KDL nodes (keybinds, plugin
          # aliases, top-level options, ...). A node is
          # { node = "name"; args ? [ ]; props ? { }; children ? [ ]; } -
          # see lib/wrapped/kdl.nix.
          settings ? [ ],
          # Named layouts as { <name> = <KDL node list>; ... }, rendered to
          # <config-dir>/layouts/<name>.kdl. A layout named "default"
          # overrides zellij's built-in default layout with no further
          # config needed.
          layouts ? { },
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
          # localLib.wrapped.kdl.renderDocument - same reasoning.
          renderDocument ? (
            let
              renderValue =
                v:
                if builtins.isBool v then
                  (if v then "true" else "false")
                else if builtins.isInt v || builtins.isFloat v then
                  toString v
                else if builtins.isString v then
                  builtins.toJSON v
                else
                  throw "pkgs/zellij/flake.nix: unsupported KDL value: ${builtins.toJSON v}";
              renderNode =
                indent:
                {
                  node,
                  args ? [ ],
                  props ? { },
                  children ? [ ],
                }:
                let
                  argsStr = lib.concatMapStringsSep " " renderValue args;
                  propsStr = lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "${k}=${renderValue v}") props);
                  head = lib.concatStringsSep " " (
                    [ node ] ++ lib.optional (argsStr != "") argsStr ++ lib.optional (propsStr != "") propsStr
                  );
                in
                if children == [ ] then
                  "${indent}${head}\n"
                else
                  "${indent}${head} {\n" + renderNodes (indent + "    ") children + "${indent}}\n";
              renderNodes = indent: nodes: lib.concatMapStrings (renderNode indent) nodes;
            in
            nodes: renderNodes "" nodes
          ),
        }:
        let
          configFile = pkgs.writeText "config.kdl" (renderDocument settings);

          # zellij resolves <config-dir>/themes and <config-dir>/layouts by
          # default, same as its normal XDG config dir - no theme_dir/
          # layout_dir directives needed in config.kdl.
          configDir = pkgs.runCommand "zellij-config-dir" { } (
            ''
              mkdir -p $out/layouts
            ''
            + lib.concatStrings (
              lib.mapAttrsToList (name: nodes: ''
                cp ${pkgs.writeText "${name}.kdl" (renderDocument nodes)} $out/layouts/${name}.kdl
              '') layouts
            )
            + lib.optionalString (colors != null) ''
              mkdir -p $out/themes
              cp ${pkgs.writeText "stylix.kdl" (substituteTemplate themeTemplate colors)} $out/themes/stylix.kdl
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
              --add-flags "--config ${configFile} --config-dir ${configDir}" \
              --suffix PATH : ${lib.makeBinPath extraPackages}
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
