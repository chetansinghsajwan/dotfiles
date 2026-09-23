{
  config,
  pkgs,
  nur,
  lib,
  ...
}:
let
  isLinux = config.dotfiles.system.isLinux;
  isDarwin = config.dotfiles.system.isDarwin;
in
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
    ./modules/programs
    ./modules/features
    ./modules/desktop
  ];

  home = {
    username = config.dotfiles.user.username;
    homeDirectory =
      if isDarwin then
        "/Users/${config.dotfiles.user.homeDir}"
      else
        "/home/${config.dotfiles.user.homeDir}";
    stateVersion = config.dotfiles.user.stateVersion;

    shellAliases = {
      cl = "clear";
      ".." = "cd ..";
      "..." = "cd ../..";
    };

    packages =
      with pkgs;
      [
        github-copilot-cli
        antigravity-cli
        codex
        claude-code
        tree
        curl
        devbox
        kanata
      ]
      ++ lib.optionals isLinux [
        efibootmgr
        exfat
      ];
  };

  # Populate the XDG wallpapers dir with the wallpaper pool, as plain
  # writable copies so the user can freely add/remove more.
  home.activation.populateWallpapers = lib.mkIf isLinux (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${config.xdg.userDirs.extraConfig.WALLPAPERS}
      run cp -rf ${config.dotfiles.theme.wallpapersDir}/. ${config.xdg.userDirs.extraConfig.WALLPAPERS}/
    ''
  );

  dotfiles.programs = {
    docker.enable = true;
    batman.enable = true;
    nixpkgs.enable = true;
    # cliphist/wl-clipboard are Wayland-only, so this has no Darwin support.
    clipboard.enable = isLinux;
  };

  programs = {
    zsh.enable = config.dotfiles.shell.program == "zsh";
    fish.enable = config.dotfiles.shell.program == "fish";
    nushell.enable = config.dotfiles.shell.program == "nushell";

    starship.enable = config.dotfiles.shell.theme == "starship";

    nh.enable = true;
    git.enable = true;
    gitui.enable = true;
    gh.enable = true;
    fd.enable = true;
    yt-dlp.enable = true;
    eza.enable = true;
    fzf.enable = true;
    lazydocker.enable = true;
    superfile.enable = true;
    yazi.enable = true;
    direnv.enable = true;
    tealdeer.enable = true;
  };

  # Desktop-independent kdeconnect: works the same whether GNOME or Hyprland
  # is running. Linux-only — the module has no Darwin support.
  services.kdeconnect = lib.mkIf isLinux {
    enable = true;
    indicator = true;
  };

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
        extraConfig.WALLPAPERS = "${homeDir}/pictures/wallpapers";
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
          "image/svg+xml" = imageApp;
          "image/bmp" = imageApp;

          "audio/mpeg" = audioApp;
          "audio/aac" = audioApp;

          "video/mpeg" = videoApp;
          "video/mp4" = videoApp;
          "video/x-msvideo" = videoApp;

          "text/plain" = textApp;
          "text/markdown" = textApp;
          "text/csv" = textApp;
          "text/html" = textApp;
        };
      };
  };
}
