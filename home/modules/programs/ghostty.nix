{ pkgs, ... }:
{
  home.packages = with pkgs; [
    ghostty
  ];

  xdg.configFile."ghostty/config" = {
    force = true;
    text = ''
      config-file = ?config-local
      window-width = 110
      window-height = 25
      window-decoration = none
      window-padding-x = 8
      window-padding-y = 8
      theme = Atom
      font-size = 16
    '';
  };
}
