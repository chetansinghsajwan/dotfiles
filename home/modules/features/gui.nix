{
  config,
  pkgs,
  lib,
  ...
}:
let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  enableGui = config.dotfiles.features.gui;
in
{
  imports = [
    ../desktop/gnome
  ];

  config = lib.mkIf enableGui {
    dotfiles.desktop.gnome.enable = isLinux;

    dotfiles.programs = {
      libreoffice.enable = true;
      vlc.enable = true;
    };

    programs = {
      firefox.enable = true;
      obsidian.enable = true;
      ghostty.enable = true;
    };

    home.packages = with pkgs; [
      sublime-merge
    ];
  };
}
