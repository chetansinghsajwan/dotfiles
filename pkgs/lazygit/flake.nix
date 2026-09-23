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

      # This repo's own lazygit customization, baked in as the default so
      # a bare `mkLazygit { inherit pkgs lib; colors = ...; }` already
      # produces the fully configured tool. Still overridable: whatever
      # `settings` the caller passes is merged on top, not a wholesale
      # replacement.
      defaultSettings = {
        git = {
          autoFetch = true;

          diffRenderers = [
            {
              # lazygit renders diffs inside its own scrollable panel, so
              # delta's own pager (which would shell out to `less`) has to
              # be disabled here; delta still picks up its styling
              # (syntax-theme, hunk-header-decoration-style, ...) from its
              # own baked config (see pkgs/delta). Note: delta's --navigate
              # doesn't work inside lazygit.
              command = "delta --paging=never";
            }
          ];
        };

        os = {
          copyToClipboardCmd = "wl-copy {{text}}";
        };

        customCommands = [
          {
            key = "l";
            context = "worktrees";
            description = "Toggle worktree lock";
            # lazygit's worktree model doesn't expose lock state, so this
            # checks `git worktree list --porcelain` itself and locks or
            # unlocks the selected worktree accordingly.
            command = ''sh -c 'p="$1"; if git worktree list --porcelain | awk -v p="$p" "\$0==\"worktree \"p{f=1;next} /^\$/{f=0} f&&/^locked/{print;exit}" | grep -q locked; then git worktree unlock "$p" && echo "Unlocked $p"; else git worktree lock "$p" && echo "Locked $p"; fi' -- {{ .SelectedWorktree.Path | quote }}'';
            output = "popup";
            outputTitle = "Worktree lock";
          }
        ];

        gui = {
          nerdFontsVersion = "3";

          # Hide the bottom keybindings line; press `?` (default optionMenu
          # binding) to view the full keybindings list in its own panel
          # instead.
          showBottomLine = false;

          # Default (2) barely moves the diff per press. lazygit binds
          # Shift+J/K, Ctrl+u/d, and PgUp/PgDn to the same scroll-main
          # handler with no way to give them different amounts, so this
          # raises the shared scroll distance for all of them at once.
          scrollHeight = 8;

          sidePanelWidth = 0.3;
          shrinkSidePanelsToContent = false;
          filterMode = "fuzzy";

          # Group panels into tabs (cycle with [ / ]), and let the number
          # jump keys (1-5) cycle through tabs directly, gitui-style,
          # instead of just re-focusing an already-active panel.
          #
          # Both [ / ] and the jump-key cycling always wrap around at the
          # ends, with no config option to stop it (as of lazygit 0.64.1).
          # Maintainers declined to add a toggle when asked upstream:
          # https://github.com/jesseduffield/lazygit/issues/3789
          sidePanels = [
            [ "status" ]
            [
              "files"
              "worktrees"
              "submodules"
            ]
            [
              "branches"
              "remotes"
              "tags"
            ]
            [
              "commits"
              "reflog"
              "stash"
            ]
          ];
          switchTabsWithPanelJumpKeys = true;
        };
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

          finalSettings = lib.recursiveUpdate defaultSettings settings;

          configFile = yamlFormat.generate "config.yml" (
            lib.recursiveUpdate finalSettings (
              lib.optionalAttrs (colors != null) { gui.theme = mkTheme colors; }
            )
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
