{
  description = "ghostty, wrapped with its config and theme baked in";

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

      themeTemplate = builtins.readFile ./theme.conf;

      # This repo's own ghostty customization, baked in as the default.
      # background-opacity/font-family/font-size come from
      # config.stylix.opacity.terminal / config.stylix.fonts.* - this
      # flake can't see that option tree, so those stay real caller
      # inputs. config-file's "?config-local" escape hatch needs
      # config.home.homeDirectory to become a real absolute path (a bare
      # relative name would resolve inside the immutable store output,
      # where nothing is ever there), so that's a caller input too.
      defaultSettings = {
        window-width = 110;
        window-height = 25;
        window-decoration = "none";
        window-padding-x = 8;
        window-padding-y = 8;
      };

      # ghostty's own config format: flat "key = value" lines, no quoting,
      # repeated keys for multi-value settings (font-family, palette) -
      # not a format pkgs.formats.* already speaks, so rendered by hand.
      renderValue = v: if builtins.isBool v then (if v then "true" else "false") else toString v;

      renderConfig =
        settings:
        builtins.concatStringsSep "\n" (
          builtins.filter (s: s != "") (
            builtins.attrValues (
              builtins.mapAttrs (
                name: value:
                if builtins.isList value then
                  builtins.concatStringsSep "\n" (map (v: "${name} = ${renderValue v}") value)
                else
                  "${name} = ${renderValue value}"
              ) settings
            )
          )
        );

      mkGhostty =
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
            builtins.replaceStrings (map (name: "@${name}@") (builtins.attrNames replacements)) (
              builtins.attrValues replacements
            ) template
          ),
        }:
        let
          finalSettings = lib.recursiveUpdate defaultSettings settings;

          # ghostty's theme file format wants hex without a leading "#"
          # (see the live-captured theme.conf this template is based on),
          # unlike every other wrapped package's colors shape.
          themeColorsNoHash = lib.mapAttrs (_: lib.removePrefix "#") colors;

          themeFile = pkgs.writeText "ghostty-stylix.conf" (substituteTemplate themeTemplate themeColorsNoHash);

          # An absolute theme path is honored directly (no XDG_CONFIG_HOME/
          # themes-dir lookup needed) - see pkgs/ghostty/flake.nix's
          # doc-comment source for why this matters: ghostty is a
          # shell-spawning parent process, so scoping a theme lookup via
          # XDG_CONFIG_HOME would leak into every program run inside every
          # terminal tab, unlike a --config-file CLI flag.
          configFile = pkgs.writeText "ghostty.conf" (
            renderConfig (finalSettings // lib.optionalAttrs (colors != null) { theme = toString themeFile; })
          );

          configFlagsList = [
            "--config-file=${configFile}"
            "--config-default-files=false"
          ];
          configFlags = lib.concatStringsSep " " configFlagsList;

          # Each flag as its own quoted C string literal - the trampoline
          # needs a real argv array, not one space-joined string (which
          # would land as a single malformed argument).
          cExtraArgs = lib.concatMapStringsSep ", " builtins.toJSON configFlagsList;
        in
        if pkgs.stdenv.isDarwin then
          pkgs.stdenv.mkDerivation {
            name = "ghostty-wrapped";
            buildCommand = ''
              mkdir -p $out/Applications
              cp -R ${pkgs.ghostty-bin}/Applications/Ghostty.app $out/Applications/Ghostty.app
              chmod -R u+w $out/Applications/Ghostty.app

              real="$out/Applications/Ghostty.app/Contents/MacOS/ghostty"
              mv "$real" "$real-real"

              sed \
                -e "s|@real@|$real-real|" \
                -e 's|@extra_args@|${cExtraArgs}|' \
                ${./trampoline.c} > trampoline.c
              $CC -O2 -o "$real" trampoline.c

              # Modifying any file inside a signed .app bundle invalidates
              # its signature; macOS's GUI launch path (RunningBoard, used
              # by Dock/Spotlight) refuses to spawn an improperly-signed
              # bundle. Re-sign ad-hoc - fine for a locally-built app with
              # no quarantine attribute, which is what nix produces here.
              /usr/bin/codesign --remove-signature "$out/Applications/Ghostty.app" || true
              /usr/bin/codesign --force --deep --sign - "$out/Applications/Ghostty.app"

              mkdir -p $out/bin
              ln -s "$out/Applications/Ghostty.app/Contents/MacOS/ghostty" $out/bin/ghostty
            '';
          }
        else
          pkgs.symlinkJoin {
            name = "ghostty-wrapped";
            paths = [ pkgs.ghostty ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/ghostty \
                --add-flags ${lib.escapeShellArg configFlags} \
                --suffix PATH : ${lib.makeBinPath extraPackages}
            '';
          };
    in
    {
      lib = { inherit mkGhostty; };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkGhostty { inherit pkgs; };
        }
      );
    };
}
