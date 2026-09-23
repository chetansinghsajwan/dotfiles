{
  description = "fzf, wrapped with its default options, theme, and shell integration baked in";

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

      # This repo's own fzf customization, baked in as the default.
      defaultSettings = {
        popup = "90%";
        border = "rounded";
        layout = "reverse";
        margin = 1;
        padding = 1;
        "preview-window" = "right:60%:noborder";
        bind = [
          "ctrl-a:select-all"
          "alt-k:preview-half-page-up"
          "alt-j:preview-half-page-down"
          "ctrl-/:toggle-preview"
        ];
      };

      # stylix's fzf mapping paints bg/bg+ as solid theme colors, which
      # blocks the terminal's transparency/acrylic for the popup. Override
      # just those two to fzf's "-1" - terminal default color - so the
      # popup blends in like the rest of the terminal, while keeping every
      # other themed color as-is.
      defaultColorOverrides = {
        bg = "-1";
        "bg+" = "-1";
      };

      mkFzf =
        {
          pkgs,
          lib ? pkgs.lib,
          # fzf's flags as an attrset, e.g. { layout = "reverse"; bind =
          # [ "ctrl-a:select-all" "alt-k:preview-half-page-up" ]; }, merged
          # over defaultSettings above. List values repeat the flag once
          # per element (for repeatable flags like --bind); bool true is a
          # bare flag, bool false is dropped; anything else renders as
          # "--key value".
          settings ? { },
          extraPackages ? [ ],
          # Base16 palette as { base00 = "#hex"; ...; base0F = "#hex"; }
          # (Stylix's `config.lib.stylix.colors.withHashtag` shape). Omit
          # for an unthemed build.
          colors ? null,
          # Per-key overrides applied on top of the base16 mapping, merged
          # over defaultColorOverrides above.
          colorOverrides ? { },
          # Absolute path to the shell history file fh (fzf.sh's history
          # picker) reads - substituted into the shipped fzf.sh in place of
          # its "@histfile@" placeholder. Omit to leave the placeholder
          # unsubstituted (fh will then fail to find its history file).
          histFile ? null,
          # localLib.wrapped.cliFlags.render - see pkgs/helix/flake.nix for
          # why this is a parameter and not a local definition.
          renderCliFlags ? (
            settings:
            lib.concatStringsSep " " (
              lib.flatten (
                lib.mapAttrsToList (
                  name: value:
                  if builtins.isList value then
                    map (v: "--${name} ${toString v}") value
                  else if builtins.isBool value then
                    lib.optional value "--${name}"
                  else
                    "--${name} ${toString value}"
                ) settings
              )
            )
          ),
        }:
        let
          finalSettings = lib.recursiveUpdate defaultSettings settings;
          finalColorOverrides = lib.recursiveUpdate defaultColorOverrides colorOverrides;

          themeColors = lib.optionalAttrs (colors != null) (mkThemeColors colors) // finalColorOverrides;

          colorArg =
            lib.optionalString (themeColors != { })
              "--color ${lib.concatStringsSep "," (lib.mapAttrsToList (k: v: "${k}:${v}") themeColors)}";

          optsString = lib.concatStringsSep " " (
            lib.optional (finalSettings != { }) (renderCliFlags finalSettings)
            ++ lib.optional (colorArg != "") colorArg
          );

          # fh's history file path is baked in here instead of read from
          # $HISTFILE at call time, so it can't silently fall back to a
          # stale/wrong file in a context where $HISTFILE isn't set.
          shellSh = pkgs.writeText "fzf.sh" (
            builtins.replaceStrings [ "@histfile@" ] [ (if histFile == null then "@histfile@" else histFile) ] (
              builtins.readFile ./fzf.sh
            )
          );
        in
        pkgs.symlinkJoin {
          name = "fzf-wrapped";
          paths = [ pkgs.fzf ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/fzf \
              --set FZF_DEFAULT_OPTS ${lib.escapeShellArg optsString} \
              --suffix PATH : ${lib.makeBinPath extraPackages}

            mkdir -p $out/share/fzf-shell
            cp ${shellSh} $out/share/fzf-shell/fzf.sh
            cp ${./fzf.zsh} $out/share/fzf-shell/fzf.zsh
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
