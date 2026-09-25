# nix-wrapper-modules' zsh wrapper has no `plugins` option and no
# initContent-style composition option - its whole config surface is raw
# zshenv/zshrc/zlogin/zlogout = { path; content; } text (see the upstream
# module's own check.nix). So plugin sourcing is baked in here directly,
# and `extraInitContent` stands in for home-manager's
# `programs.zsh.initContent`: every other repo module that used to append
# to that sets this instead, decoupling them from the wrapper's own
# option names. Order matches home-manager's own plugins module (plugins
# sourced before user initContent).
{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.extraInitContent = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = ''
      Extra shell code appended to the generated .zshrc, after plugin
      initialization. The wrapper-native equivalent of home-manager's
      programs.zsh.initContent.
    '';
  };

  config.zshrc.content = ''
    source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
  ''
  + config.extraInitContent;
}
