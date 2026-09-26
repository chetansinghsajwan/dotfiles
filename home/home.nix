{
  config,
  pkgs,
  nur,
  lib,
  pkgs-wrapped,
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
    ./modules/features
    ./modules/desktop

    # Every pkgs/<name>/ package (see pkgs/flake.nix) - self-contained
    # home-manager modules, imported directly rather than through a
    # one-line home/modules/programs/<name>.nix pass-through. Order matters
    # here: modules setting wrappers.zsh.extraInitContent (yazi, fzf, git,
    # docker, nixpkgs, starship, direnv, clipboard) concatenate their rc
    # snippets in this list's order, since none of them use mkOrder.
    pkgs-wrapped.homeModules.yazi
    pkgs-wrapped.homeModules.lazygit
    pkgs-wrapped.homeModules.btop
    pkgs-wrapped.homeModules.helix
    pkgs-wrapped.homeModules.tealdeer
    pkgs-wrapped.homeModules.eza
    pkgs-wrapped.homeModules.fzf
    pkgs-wrapped.homeModules.git
    pkgs-wrapped.homeModules.zellij
    pkgs-wrapped.homeModules.zsh
    pkgs-wrapped.homeModules.op
    pkgs-wrapped.homeModules.pv
    pkgs-wrapped.homeModules.docker
    pkgs-wrapped.homeModules.nixpkgs
    pkgs-wrapped.homeModules.starship
    pkgs-wrapped.homeModules.direnv
    pkgs-wrapped.homeModules.batman
    pkgs-wrapped.homeModules.zed
    pkgs-wrapped.homeModules.vscode
    pkgs-wrapped.homeModules.vlc
    pkgs-wrapped.homeModules.ghostty
    pkgs-wrapped.homeModules.firefox
    pkgs-wrapped.homeModules.dconf-editor
    pkgs-wrapped.homeModules.epiphany
    pkgs-wrapped.homeModules.gnome-terminal
    pkgs-wrapped.homeModules.gnome-text-editor
    pkgs-wrapped.homeModules.kanata-layer-indicator
    pkgs-wrapped.homeModules.libreoffice
    pkgs-wrapped.homeModules.nbfc-linux
    pkgs-wrapped.homeModules.clipboard
  ];

  # The imports above only wire each wrapped package's config up; each
  # one still defaults to disabled (matching every other wrapper module's
  # own default) until switched on here.
  wrappers = {
    yazi.enable = true;
    lazygit.enable = true;
    btop.enable = true;
    helix.enable = true;
    tealdeer.enable = true;
    eza.enable = true;
    fzf.enable = true;
    git.enable = true;
    zellij.enable = true;
    zsh.enable = config.dotfiles.shell.program == "zsh";
    zed.enable = config.dotfiles.features.dev && config.dotfiles.features.gui;
    vscode.enable = config.dotfiles.features.dev && config.dotfiles.features.gui;
  };

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

    nh.enable = true;
    gitui.enable = true;
    gh.enable = true;
    fd.enable = true;
    yt-dlp.enable = true;
    lazydocker.enable = true;
    superfile.enable = true;
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
