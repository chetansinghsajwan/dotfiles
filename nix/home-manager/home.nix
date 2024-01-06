{ config, pkgs, ... }:
{
    programs.home-manager.enable = true;

    home.username = "chetan";
    home.homeDirectory = "/home/chetan";
    home.stateVersion = "23.05";

    imports = [
        ./core.nix
        ./env/gnome.nix
        ./packages/git.nix
        ./packages/obsidian.nix
        ./packages/vlc.nix
    ];

    nixpkgs.config.allowUnfree = true;
    home.packages = with pkgs; [
        neovim
        gh
        vscode
        firefox
        jellyfin
        bitwarden
        bottles
        protonvpn-gui
        protonvpn-cli
        spotify
        cascadia-code
    ];
}
