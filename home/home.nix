{
  config,
  pkgs,
  nur,
  lib,
  localLib,
  ...
}:
let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
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
  ]
  ++ localLib.importDir ./modules/features
  ++ localLib.importDir ./modules/programs;

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
        yt-dlp
        tree
        curl
        gh
        git-lfs
        nixpkgs-fmt
        poppins
        devbox
      ]
      ++ lib.optionals isLinux [
        efibootmgr
        curtail
        exfat
      ];
  };

  dotfiles.programs = {
    tldr.enable = true;
  };

  programs = {
    zsh.enable = config.dotfiles.shell.program == "zsh";
    fish.enable = config.dotfiles.shell.program == "fish";
    nushell.enable = config.dotfiles.shell.program == "nushell";

    starship.enable = config.dotfiles.shell.theme == "starship";

    git.enable = true;
    neovim.enable = true;
    atuin.enable = true;
    btop.enable = true;
    eza.enable = true;
    fzf.enable = true;
    lazydocker.enable = true;
    lazygit.enable = true;
    superfile.enable = true;
    yazi.enable = true;
    zoxide.enable = true;
    direnv.enable = true;
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
