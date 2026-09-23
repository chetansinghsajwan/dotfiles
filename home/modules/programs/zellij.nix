{
  config,
  pkgs,
  lib,
  localLib,
  zellij-wrapped,
  ...
}:
let
  # zellij-forgot shows a floating keybind cheatsheet on demand; the built-in
  # compact-bar tooltip is broken on zellij >=0.44.1 (zellij-org/zellij#5229).
  zellij-forgot = pkgs.fetchurl {
    url = "https://github.com/karimould/zellij-forgot/releases/download/0.4.2/zellij_forgot.wasm";
    sha256 = "1ns9wjn1ncjapqpp9nn9kyhqydvl0fbnyiavd0lc3gcxa52l269i";
  };
in
{
  home.packages = [
    (zellij-wrapped.lib.mkZellij {
      inherit pkgs lib;
      inherit (localLib.wrapped.base16) substituteTemplate;
      inherit (localLib.wrapped.kdl) renderDocument;

      colors = config.lib.stylix.colors.withHashtag;

      settings = [
        {
          node = "keybinds";
          children = [
            {
              # Default tab mode groups h/Left/Up/k -> previous tab,
              # l/Right/Down/j -> next tab. jk is dropped entirely (kanata
              # handles that now); Up/Down are reversed relative to the
              # default so Up goes to the next tab.
              #
              # GoToNextTab/GoToPreviousTab always wrap around at the ends;
              # there's no config option to stop that as of zellij 0.45.0.
              # A `tab_cycle_wrap false` option was proposed upstream but
              # is unmerged: see https://github.com/zellij-org/zellij/pull/4815.
              # Revisit once it lands.
              node = "tab";
              children = [
                {
                  node = "unbind";
                  args = [
                    "j"
                    "k"
                  ];
                }
                {
                  node = "bind";
                  args = [ "Up" ];
                  children = [ { node = "GoToNextTab"; } ];
                }
                {
                  node = "bind";
                  args = [ "Down" ];
                  children = [ { node = "GoToPreviousTab"; } ];
                }
              ];
            }
            {
              node = "shared_except";
              args = [ "locked" ];
              children = [
                {
                  # Ctrl+/ avoids colliding with typing a literal "?" in a pane.
                  node = "bind";
                  args = [ "Ctrl /" ];
                  children = [
                    {
                      node = "LaunchOrFocusPlugin";
                      args = [ "file:${zellij-forgot}" ];
                      children = [
                        {
                          node = "floating";
                          args = [ true ];
                        }
                      ];
                    }
                  ];
                }
              ];
            }
          ];
        }
      ];

      # Compact bar merges the tab-bar and status-bar into a single line at the
      # top, with a blank borderless row inserted after it so content doesn't
      # sit flush against it.
      layouts.default = [
        {
          node = "layout";
          children = [
            {
              node = "pane";
              props = {
                size = 1;
                borderless = true;
              };
              children = [
                {
                  node = "plugin";
                  props = {
                    location = "compact-bar";
                  };
                }
              ];
            }
            { node = "pane"; }
          ];
        }
      ];
    })
  ];

  home.shellAliases = {
    z = "zellij";
  };
}
