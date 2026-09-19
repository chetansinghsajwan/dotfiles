_: {
  programs.zellij = {
    # enableBashIntegration = config.dotfiles.shell.program == "bash";
    # enableZshIntegration = config.dotfiles.shell.program == "zsh";
    # enableFishIntegration = config.dotfiles.shell.program == "fish";
    # exitShellOnExit = true;

    # Default tab mode binds k -> previous tab, j -> next tab; reverse them.
    extraConfig = ''
      keybinds {
          tab {
              bind "j" { GoToPreviousTab; }
              bind "k" { GoToNextTab; }
          }
      }
    '';

    # Compact bar merges the tab-bar and status-bar into a single line at the
    # top, with a blank borderless row inserted after it so content doesn't
    # sit flush against it.
    layouts.default = ''
      layout {
          pane size=1 borderless=true {
              plugin location="compact-bar" {
                  tooltip "?"
              }
          }
          pane
      }
    '';
  };

  home.shellAliases = {
    z = "zellij";
  };
}
