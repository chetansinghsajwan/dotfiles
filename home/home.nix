{
  config,
  pkgs,
  nur,
  lib,
  userConfig ? { },
  preferencesOverride ? { },
  isLinux ? false,
  ...
}:
let
  cfgBase = import ./config;
  cfg = cfgBase // {
    user = cfgBase.user // userConfig;
    preferences = cfgBase.preferences // {
      features = cfgBase.preferences.features // preferencesOverride;
    };
  };

  # Conditionally import features based on preferences
  featuresImports =
    with cfg.preferences.features;
    [
      ./modules/features/base.nix
    ]
    ++ (if dev then [ ./modules/features/dev.nix ] else [ ])
    ++ (if gui && isLinux then [ ./modules/features/gui.nix ] else [ ])
    ++ (if gaming && isLinux then [ ./modules/features/gaming.nix ] else [ ]);
in
{
  programs.home-manager.enable = true;

  home.username = cfg.user.username;
  home.homeDirectory = cfg.user.homeDirectory;
  home.stateVersion = cfg.user.stateVersion;

  programs.git.settings.user.name = cfg.user.username;
  programs.git.settings.user.email = cfg.user.email;

  nix.enable = false;
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "python3.12-youtube-dl-2021.12.17"
  ];

  nixpkgs.overlays = [
    nur.overlays.default
  ];

  imports =
    featuresImports
    ++ lib.optionals (isLinux && cfg.preferences.features.gui) [
      ./module/programs/dconf-editor.nix
    ];

  home.packages =
    with pkgs;
    lib.optionals isLinux [
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
