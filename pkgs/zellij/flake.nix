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

      # This repo's own zellij customization, baked in as the default so a
      # bare `mkZellij { inherit pkgs lib; colors = ...; }` already
      # produces the fully configured tool. `settings` is a *list* of
      # top-level KDL nodes (not an attrset), so "overridable but
      # defaulted" here means concatenation - whatever the caller passes
      # is appended after these, not merged key-by-key.
      mkDefaultSettings =
        pkgs:
        let
          # zellij-forgot shows a floating keybind cheatsheet on demand;
          # the built-in compact-bar tooltip is broken on zellij >=0.44.1
          # (zellij-org/zellij#5229).
          zellij-forgot = pkgs.fetchurl {
            url = "https://github.com/karimould/zellij-forgot/releases/download/0.4.2/zellij_forgot.wasm";
            sha256 = "1ns9wjn1ncjapqpp9nn9kyhqydvl0fbnyiavd0lc3gcxa52l269i";
          };
        in
        [
          {
            node = "keybinds";
            children = [
              {
                # Default tab mode groups h/Left/Up/k -> previous tab,
                # l/Right/Down/j -> next tab. jk is dropped entirely
                # (kanata handles that now); Up/Down are reversed relative
                # to the default so Up goes to the next tab.
                #
                # GoToNextTab/GoToPreviousTab always wrap around at the
                # ends; there's no config option to stop that as of zellij
                # 0.45.0. A `tab_cycle_wrap false` option was proposed
                # upstream but is unmerged: see
                # https://github.com/zellij-org/zellij/pull/4815. Revisit
                # once it lands.
                node = "tab";
                children = [
                  {
                    node = "unbind";
                    args = [
                      "j"
                      "k"
                    ];
                  }
                  {
                    node = "bind";
                    args = [ "Up" ];
                    children = [ { node = "GoToNextTab"; } ];
                  }
                  {
                    node = "bind";
                    args = [ "Down" ];
                    children = [ { node = "GoToPreviousTab"; } ];
                  }
                ];
              }
              {
                node = "shared_except";
                args = [ "locked" ];
                children = [
                  {
                    # Ctrl+/ avoids colliding with typing a literal "?" in
                    # a pane.
                    node = "bind";
                    args = [ "Ctrl /" ];
                    children = [
                      {
                        node = "LaunchOrFocusPlugin";
                        args = [ "file:${zellij-forgot}" ];
                        children = [
                          {
                            node = "floating";
                            args = [ true ];
                          }
                        ];
                      }
                    ];
                  }
                ];
              }
            ];
          }
        ];

      # Compact bar merges the tab-bar and status-bar into a single line
      # at the top, with a blank borderless row inserted after it so
      # content doesn't sit flush against it.
      defaultLayouts = {
        default = [
          {
            node = "layout";
            children = [
              {
                node = "pane";
                props = {
                  size = 1;
                  borderless = true;
                };
                children = [
                  {
                    node = "plugin";
                    props = {
                      location = "compact-bar";
                    };
                  }
                ];
              }
              { node = "pane"; }
            ];
          }
        ];
      };

      mkZellij =
        {
          pkgs,
          lib ? pkgs.lib,
          # config.kdl's content as a list of KDL nodes (keybinds, plugin
          # aliases, top-level options, ...), appended after
          # mkDefaultSettings above. A node is { node = "name"; args ? [ ];
          # props ? { }; children ? [ ]; } - see lib/wrapped/kdl.nix.
          settings ? [ ],
          # Named layouts as { <name> = <KDL node list>; ... }, merged
          # over defaultLayouts above and rendered to
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
          finalSettings = mkDefaultSettings pkgs ++ settings;
          finalLayouts = lib.recursiveUpdate defaultLayouts layouts;

          configFile = pkgs.writeText "config.kdl" (renderDocument finalSettings);

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
              '') finalLayouts
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
