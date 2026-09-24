# This repo's own lazygit customization. Theming is set separately by
# whatever imports this (see flake.nix's `homeModules.default`), since it
# needs the outer config's `colors` - a plain wrapper module like this one
# only ever sees its own submodule config, not the config around it.
{
  config = {
    settings = {
      git = {
        autoFetch = true;

        diffRenderers = [
          {
            # lazygit renders diffs inside its own scrollable panel, so
            # delta's own pager (which would shell out to `less`) has to be
            # disabled here; delta still picks up its styling (syntax-theme,
            # hunk-header-decoration-style, ...) from the [delta] section
            # home-manager writes into gitconfig (see delta.nix). Note:
            # delta's --navigate doesn't work inside lazygit.
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
        # Shift+J/K, Ctrl+u/d, and PgUp/PgDn to the same scroll-main handler
        # with no way to give them different amounts, so this raises the
        # shared scroll distance for all of them at once.
        scrollHeight = 8;

        sidePanelWidth = 0.3;
        shrinkSidePanelsToContent = false;
        filterMode = "fuzzy";

        # Group panels into tabs (cycle with [ / ]), and let the number jump
        # keys (1-5) cycle through tabs directly, gitui-style, instead of
        # just re-focusing an already-active panel.
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
  };
}
