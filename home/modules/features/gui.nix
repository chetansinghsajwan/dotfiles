{ pkgs, ... }:
{
  imports = [
    ../programs/firefox.nix
    ../programs/vlc.nix
    ../programs/gnome-text-editor.nix
    ../programs/obsidian.nix
    ../programs/epiphany.nix
    ../desktop/gnome.nix
  ];

  home.packages = with pkgs; [
    libreoffice
    yt-dlp
    # fonts
    poppins
    jetbrains-mono
    nerd-fonts.jetbrains-mono
  ];
}
