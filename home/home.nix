{
  config,
  pkgs,
  nur,
  lib,
  isLinux ? false,
  ...
}:
{
  programs.home-manager.enable = true;

  nix.enable = false;
  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    nur.overlays.default
  ];

  imports = [
    ../config
    ./modules/stylix.nix
    ./modules/features/base.nix
    ./modules/features/dev.nix
    ./modules/features/gui.nix
    ./modules/features/gaming.nix
  ];

  home.username = config.dotfiles.user.username;
  home.homeDirectory = config.dotfiles.user.homeDirectory;
  home.stateVersion = config.dotfiles.user.stateVersion;

  home.packages =
    with pkgs;
    [
      github-copilot-cli
      antigravity-cli
      codex
      claude-code
    ]
    ++ lib.optionals isLinux [
      efibootmgr
      curtail
      sublime-merge
      exfat
    ];

  xdg = {
    enable = true;
  }
  // lib.optionalAttrs isLinux {
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
        setSessionVariables = false;
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
