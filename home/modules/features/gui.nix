{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../programs/firefox.nix
    ../programs/vlc.nix
    ../programs/gnome-text-editor.nix
    ../programs/obsidian.nix
    ../programs/epiphany.nix
    ../programs/ghostty.nix
    ../desktop/gnome.nix
  ];

  config = lib.mkIf config.dotfiles.features.gui {

    home.packages = with pkgs; [
      libreoffice
      yt-dlp
      # fonts
      poppins
      jetbrains-mono
      nerd-fonts.jetbrains-mono
    ];
  };
}
