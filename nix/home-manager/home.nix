{ config, pkgs, ... }:
{
    programs.home-manager.enable = true;

    home.username = "chetan";
    home.homeDirectory = "/home/chetan";
    home.stateVersion = "23.11";

    # nix.package = pkgs.nix;
    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    imports = [
        ./core.nix
        ./env/gnome.nix
        ./packages/git.nix
        ./packages/obsidian.nix
        ./packages/vlc.nix
        ./packages/nvim.nix
    ];

    nixpkgs.config.allowUnfree = true;
    home.packages = with pkgs; [
        todoist
	todoist-electron
        github-desktop
        gh
        teams-for-linux
        vscode
        firefox
        bitwarden
        bottles
        protonvpn-gui
        protonvpn-cli
        spotify
        cascadia-code
    ];
}
