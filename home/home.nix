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
        ./packages/eza.nix
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
        google-chrome
        curtail
        libreoffice
        thunderbird
        youtube-dl
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

        mimeApps =
            let
                filesApp = "org.gnome.Nautilus.desktop";
                audioApp = "io.bassi.Amberol.desktop";
                videoApp = "vlc.desktop";
                imageApp = "org.gnome.Loupe.desktop";
                textApp = "org.gnome.TextEditor.desktop";
                pdfApp = "org.gnome.Evince.desktop";
            in
        {
            enable = true;
            defaultApplications =
            {
                "application/pdf" = pdfApp;

                "inode/directory" = filesApp;

                "image/png" = imageApp;
                "image/jpeg" = imageApp;
                "image/svg" = imageApp;
                "image/bmp" = imageApp;

                "audio/mpeg" = audioApp;
                "audio/aac" = audioApp;

                "video/mpeg" = videoApp;
                "video/mp4" = videoApp;
                "video/x-msvideo" = videoApp;

                "text/plain" = textApp;
                "text/md" = textApp;
                "text/csv" = textApp;
                "text/html" = textApp;
            };
        };
    };
}
