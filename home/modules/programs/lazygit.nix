# home/modules/programs/lazygit.nix
_: {
  programs.lazygit = {
    settings = {
      git = {
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

      gui = {
        # Group panels into tabs (cycle with [ / ]), and let the number jump
        # keys (1-5) cycle through tabs directly, gitui-style, instead of
        # just re-focusing an already-active panel.
        sidePanels = [
          [ "status" ]
          [ "files" "worktrees" "submodules" ]
          [ "branches" "remotes" "tags" ]
          [ "commits" "reflog" ]
          [ "stash" ]
        ];
        switchTabsWithPanelJumpKeys = true;
      };
    };
  };
}
