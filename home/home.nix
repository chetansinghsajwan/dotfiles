{ config, pkgs, nur, ... }:
{
  programs.home-manager.enable = true;

  home.username = "chetansinghsajwan";
  home.homeDirectory = "/home/chetansinghsajwan";
  home.stateVersion = "23.11";

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "python3.12-youtube-dl-2021.12.17"
  ];

  nixpkgs.overlays = [
    nur.overlays.default
  ];

  imports = [
    ./env/gnome/gnome.nix
    ./packages/zsh.nix
    ./packages/git.nix
    ./packages/obsidian.nix
    ./packages/vlc.nix
    ./packages/neovim.nix
    ./packages/eza.nix
    ./packages/firefox.nix
    ./packages/vscode.nix
  ];

  home.packages = with pkgs; [
    efibootmgr
    todoist-electron
    gh
    teams-for-linux
    bitwarden
    bottles
    protonvpn-gui
    protonvpn-cli
    nixpkgs-fmt
    google-chrome
    curtail
    libreoffice
    youtube-dl
    tree
    sublime-merge
    exfat

    # fonts
    poppins
    jetbrains-mono
    nerd-fonts.jetbrains-mono
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

    configFile."mimeapps.list".force = true;
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
        defaultApplications = {
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
