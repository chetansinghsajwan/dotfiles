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

      # This repo's own helix customization, baked in as the default so a
      # bare `mkHelix { inherit pkgs lib; colors = ...; settings.editor =
      # { rulers = ...; text-width = ...; scroll-lines = ...; line-number
      # = ...; }; }` already produces the fully configured tool. The four
      # editor.* leaves left out here (rulers, text-width, scroll-lines,
      # line-number) come from config.dotfiles.editor.* - this flake can't
      # see that repo-level option tree, so those stay real caller inputs,
      # merged on top of this default via recursiveUpdate.
      defaultSettings = {
        editor = {
          mouse = true;
          middle-click-paste = false;
          cursorline = true;
          cursorcolumn = true;
          continue-comments = true;
          true-color = true;
          bufferline = "multiple";
          color-modes = true;
          default-line-ending = "lf";
          insert-final-newline = true;
          trim-final-newlines = true;
          trim-trailing-whitespace = true;
          popup-border = "all";

          cursor-shape = {
            normal = "block";
            insert = "bar";
            select = "underline";
          };

          auto-save = {
            focus-lost = true;
            after-delay.enable = true;
          };

          indent-guides.render = true;

          statusline = {
            left = [
              "mode"
              "spinner"
              "file-name"
            ];
            center = [ ];
            right = [
              "diagnostics"
              "selections"
              "position"
              "file-encoding"
            ];
          };
        };

        keys =
          let
            navigation = {
              "C-h" = "move_prev_word_start";
              "C-l" = "move_next_word_start";
              "C-j" = "page_cursor_half_down";
              "C-k" = "page_cursor_half_up";
              "C-A-h" = "goto_line_start";
              "C-A-l" = "goto_line_end";
              "C-A-j" = "goto_last_line";
              "C-A-k" = "goto_file_start";
              "A-j" = "goto_next_function";
              "A-k" = "goto_prev_function";
            };
          in
          {
            normal = navigation;
            select = navigation;
          };
      };

      defaultExtraPackages =
        pkgs: with pkgs; [
          nil
          lua-language-server
          bash-language-server
          marksman
          vscode-langservers-extracted
          yaml-language-server
        ];

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
          # opacity.terminal != 1.0. This repo always wants it on.
          transparent ? true,
          # localLib.wrapped.base16.substituteTemplate - passed in rather
          # than defined here since sibling pkgs/<name> flakes can't share
          # files with each other (a `path:./pkgs/<name>` input is copied
          # as only that subtree). See lib/wrapped/default.nix. Defaults to
          # the same one-line implementation so `packages.default` below
          # (and standalone `nix build`) still works without a caller.
          substituteTemplate ? (
            template: replacements:
            builtins.replaceStrings (map (name: "@${name}@") (
              builtins.attrNames replacements
            )) (builtins.attrValues replacements) template
          ),
        }:
        let
          tomlFormat = pkgs.formats.toml { };

          finalSettings = lib.recursiveUpdate defaultSettings settings;

          configFile = tomlFormat.generate "config.toml" (
            finalSettings // lib.optionalAttrs (colors != null) { theme = "stylix"; }
          );

          themeToml = pkgs.writeText "stylix.toml" (substituteTemplate themeTemplate colors);

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
              --suffix PATH : ${lib.makeBinPath (defaultExtraPackages pkgs ++ extraPackages)}

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
