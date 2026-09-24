{
  config,
  pkgs,
  lib,
  git-wrapped,
  delta-wrapped,
  ...
}:
let
  isWSL = config.dotfiles.system.isWsl;

  deltaPkg = delta-wrapped.lib.mkDelta { inherit pkgs lib; };

  gitPkg = git-wrapped.lib.mkGit {
    inherit pkgs lib;

    # The rest of git's config is baked into pkgs/git itself; only these
    # come from config.dotfiles.*, this host's isDarwin/gnome/isWSL
    # branches, or the sibling wrapped delta package - none of which
    # pkgs/git has any way to see.
    settings = {
      user = {
        name = config.dotfiles.user.displayName;
        email = config.dotfiles.user.git.email;
      };

      credential.credentialStore =
        if config.dotfiles.system.isDarwin then
          "keychain"
        else if config.dotfiles.desktop.gnome.enable then
          "secretservice"
        else if isWSL then
          "gpg"
        else
          "cache";

      # Was programs.delta.enable's generated pager/interactive wiring -
      # points at the wrapped delta binary directly (it reads its own
      # baked --config instead of this file's now-absent [delta] section).
      interactive.diffFilter = "${deltaPkg}/bin/delta --color-only";
      pager = {
        diff = "${deltaPkg}/bin/delta";
        log = "${deltaPkg}/bin/delta";
        show = "${deltaPkg}/bin/delta";
        blame = "${deltaPkg}/bin/delta";
      };
    };
  };
in
{
  home.packages = [
    gitPkg
    deltaPkg
    pkgs.git-credential-manager
  ];

  programs.bash.initExtra = "source ${gitPkg}/share/git-shell/git.sh";
  # git.zsh (ZLE widgets/bindkey) is zsh-only, so it isn't sourced into bash.
  programs.zsh.initContent = ''
    source ${gitPkg}/share/git-shell/git.sh
    source ${gitPkg}/share/git-shell/git.zsh
  '';

  programs.gpg.enable = isWSL;

  programs.password-store = {
    enable = isWSL;
    settings = { };
  };

  services.gpg-agent = lib.mkIf isWSL {
    enable = true;
    enableSshSupport = false;
    # pinentry-curses draws on the controlling tty, which collides with
    # lazygit's own terminal UI (broken input, corrupted redraws). WSLg
    # provides a display, so use a GUI pinentry that pops its own window.
    pinentry.package = pkgs.pinentry-qt;
  };
}
