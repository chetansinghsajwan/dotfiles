{ pkgs, ... }:
let
  # zellij-forgot shows a floating keybind cheatsheet on demand; the built-in
  # compact-bar tooltip is broken on zellij >=0.44.1 (zellij-org/zellij#5229).
  zellij-forgot = pkgs.fetchurl {
    url = "https://github.com/karimould/zellij-forgot/releases/download/0.4.2/zellij_forgot.wasm";
    sha256 = "1ns9wjn1ncjapqpp9nn9kyhqydvl0fbnyiavd0lc3gcxa52l269i";
  };
in
{
  programs.zellij = {
    # enableBashIntegration = config.dotfiles.shell.program == "bash";
    # enableZshIntegration = config.dotfiles.shell.program == "zsh";
    # enableFishIntegration = config.dotfiles.shell.program == "fish";
    # exitShellOnExit = true;

    # Default tab mode groups h/Left/Up/k -> previous tab, l/Right/Down/j ->
    # next tab. jk is dropped entirely (kanata handles that now); Up/Down are
    # reversed relative to the default so Up goes to the next tab.
    #
    # GoToNextTab/GoToPreviousTab always wrap around at the ends; there's no
    # config option to stop that as of zellij 0.45.0. A `tab_cycle_wrap false`
    # option was proposed upstream but is unmerged: see
    # https://github.com/zellij-org/zellij/pull/4815. Revisit once it lands.
    extraConfig = ''
      keybinds {
          // Default tab mode binds k -> previous tab, j -> next tab; reverse them.
          tab {
              unbind "j" "k"
              bind "Up" { GoToNextTab; }
              bind "Down" { GoToPreviousTab; }
          }

          // Ctrl+/ avoids colliding with typing a literal "?" in a pane.
          shared_except "locked" {
              bind "Ctrl /" {
                  LaunchOrFocusPlugin "file:~/zellij-plugins/zellij_forgot.wasm" {
                      floating true
                  }
              }
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

  home.file."zellij-plugins/zellij_forgot.wasm".source = zellij-forgot;

  home.shellAliases = {
    z = "zellij";
  };
}
