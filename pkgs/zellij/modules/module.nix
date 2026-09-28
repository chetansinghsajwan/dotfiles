# This repo's own zellij customization plus nix-wrapper-modules' generic
# wrapper mechanism (wrapper-module.nix, since nix-wrapper-modules ships
# no native zellij module) - so this one file is the complete zellij
# wrapper, and callers only ever need to reference it, not also list
# wrapper-module.nix separately.
{
  imports = [ ./wrapper-module.nix ];

  config = {
    # Default tab mode groups h/Left/Up/k -> previous tab, l/Right/Down/j ->
    # next tab. jk is dropped entirely (kanata handles that now); Up/Down are
    # reversed relative to the default so Up goes to the next tab.
    #
    # GoToNextTab/GoToPreviousTab always wrap around at the ends; there's no
    # config option to stop that as of zellij 0.45.0. A `tab_cycle_wrap false`
    # option was proposed upstream but is unmerged: see
    # https://github.com/zellij-org/zellij/pull/4815. Revisit once it lands.
    configKdl = ''
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
}
