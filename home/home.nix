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
        ./packages/zsh.nix
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
        nerdfonts
        nixpkgs-fmt
        unityhub
        dotnet-sdk_8
        google-chrome
        curtail
        libreoffice
        thunderbird
    ];

    xdg = {
        enable = true;

        userDirs =
        let
            homeDir = config.home.homeDirectory;
        in
        {
            enable = true;
            createDirectories = true;
            desktop = "${homeDir}/desktop";
            documents = "${homeDir}/documents";
            download = "${homeDir}/downloads";
            music = "${homeDir}/music";
            pictures = "${homeDir}/pictures";
            publicShare = "${homeDir}/public";
            templates = "${homeDir}/templates";
            videos = "${homeDir}/videos";
        };
    };
}
