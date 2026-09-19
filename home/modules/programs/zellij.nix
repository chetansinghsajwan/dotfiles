_: {
  programs.zellij = {
    # enableBashIntegration = config.dotfiles.shell.program == "bash";
    # enableZshIntegration = config.dotfiles.shell.program == "zsh";
    # enableFishIntegration = config.dotfiles.shell.program == "fish";
    # exitShellOnExit = true;

    # Default tab mode groups h/Left/Up/k -> previous tab, l/Right/Down/j ->
    # next tab. jk is dropped entirely (kanata handles that now); Up/Down are
    # reversed relative to the default so Up goes to the next tab.
    extraConfig = ''
      keybinds {
          tab {
              unbind "j" "k"
              bind "Up" { GoToNextTab; }
              bind "Down" { GoToPreviousTab; }
          }
      }
    '';

    # Compact bar merges the tab-bar and status-bar into a single line at the
    # top, with a blank borderless row inserted after it so content doesn't
    # sit flush against it.
    layouts.default = ''
      layout {
          pane size=1 borderless=true {
              plugin location="compact-bar"
          }
          pane
      }
    '';
  };

  home.shellAliases = {
    z = "zellij";
  };
}
