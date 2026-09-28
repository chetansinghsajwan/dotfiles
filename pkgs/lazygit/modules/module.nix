# This repo's own lazygit customization (settings, theme) plus
# nix-wrapper-modules' generic wrapper mechanism (wrapper-module.nix,
# since nix-wrapper-modules ships no native lazygit module) - so this one
# file is the complete lazygit wrapper, and callers only ever need to
# reference it, not also list wrapper-module.nix separately. Theming is
# this module's own responsibility end to end: `colors` defaults to this
# repo's own default base16 theme, so a standalone build is themed out of
# the box with no outer config needed at all. Whatever imports this (see
# flake.nix's `homeModules.default`) may still override `colors` with a
# live palette (e.g. Stylix's) when one is available.
{
  config,
  lib,
  ...
}:
{
  imports = [
    ./wrapper-module.nix

    # Purely so `colors` below can default to config.dotfiles.theme.colors
    # - the same config/default.nix option this repo's home-manager hosts
    # already get, just merged into this wrapper module's own isolated
    # evalModules instead of home-manager's. lib/config are already
    # shared module args, so this needs no separate evalModules call or
    # specialArgs threading.
    ../../../config

    # Sets config.settings.gui.theme from config.colors.
    ./theme.nix
  ];

  options.colors = lib.mkOption {
    type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
    default = config.dotfiles.theme.colors;
    defaultText = lib.literalExpression "config.dotfiles.theme.colors";
    description = ''
      base16 palette as { base00 = "#hex"; ...; }, e.g.
      `config.lib.stylix.colors.withHashtag`. Defaults to this repo's own
      config.dotfiles.theme.colors; set to null to leave lazygit
      unthemed (its own defaults) instead.
    '';
  };

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
