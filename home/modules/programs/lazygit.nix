# home/modules/programs/lazygit.nix
_: {
  programs.lazygit = {
    settings = {
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
