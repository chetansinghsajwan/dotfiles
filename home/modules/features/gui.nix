{
  config,
  lib,
  ...
}:
let
  isLinux = config.dotfiles.system.isLinux;
  enableGui = config.dotfiles.features.gui;
in
{
  imports = [
    ../desktop/gnome
    ../desktop/hyprland
  ];

  config = lib.mkIf enableGui {
    dotfiles.desktop.hyprland.enable = isLinux;

    dotfiles.programs = {
      libreoffice.enable = isLinux;
      vlc.enable = isLinux;
    };

    programs = {
      firefox.enable = true;
      obsidian.enable = true;
      ghostty.enable = true;
    };
  };
}
