{
  config,
  pkgs,
  nur,
  lib,
  yazi-wrapped,
  lazygit-wrapped,
  btop-wrapped,
  helix-wrapped,
  tealdeer-wrapped,
  eza-wrapped,
  fzf-wrapped,
  git-wrapped,
  zellij-wrapped,
  zsh-wrapped,
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

    # Wrapped packages (pkgs/<name>/, nix-wrapper-modules) - self-contained
    # home-manager modules, imported directly rather than through a
    # one-line home/modules/programs/<name>.nix pass-through.
    yazi-wrapped.homeModules.default
    lazygit-wrapped.homeModules.default
    btop-wrapped.homeModules.default
    helix-wrapped.homeModules.default
    tealdeer-wrapped.homeModules.default
    eza-wrapped.homeModules.default
    fzf-wrapped.homeModules.default
    git-wrapped.homeModules.default
    zellij-wrapped.homeModules.default
    zsh-wrapped.homeModules.default
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

    starship.enable = config.dotfiles.shell.theme == "starship";

    nh.enable = true;
    gitui.enable = true;
    gh.enable = true;
    fd.enable = true;
    yt-dlp.enable = true;
    lazydocker.enable = true;
    superfile.enable = true;
    direnv.enable = true;
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
