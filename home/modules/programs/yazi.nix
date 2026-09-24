{
  config,
  lib,
  pkgs,
  yazi-wrapped,
  ...
}:
{
  home.packages = [
    (yazi-wrapped.lib.mkYazi {
      inherit pkgs;
      colors = config.lib.stylix.colors.withHashtag;
    })
    pkgs._7zz # archive entry/method listing for the properties panel
    pkgs.ffmpeg-headless # ffprobe, for media duration/codec in the properties panel
  ];

  # yazi's shellWrapperName feature (a `y` function that cd's the shell to
  # wherever yazi was quit from) was home-manager's `programs.yazi` doing
  # this generation for us; wrapping via nix-wrapper-modules bypasses that,
  # so it's reproduced by hand here from the same generated scripts.
  home.file = {
    ".config/yazi/y.zsh".source = "${yazi-wrapped}/y.zsh";
    ".config/yazi/y.fish".source = "${yazi-wrapped}/y.fish";
    ".config/yazi/y.nu".source = "${yazi-wrapped}/y.nu";
  };

  programs.zsh.initContent = lib.mkIf (config.dotfiles.shell.program == "zsh") ''
    source ~/.config/yazi/y.zsh
  '';

  programs.fish.interactiveShellInit = lib.mkIf (config.dotfiles.shell.program == "fish") ''
    source ~/.config/yazi/y.fish
  '';

  programs.nushell.extraConfig = lib.mkIf (config.dotfiles.shell.program == "nushell") (
    builtins.readFile "${yazi-wrapped}/y.nu"
  );
}
