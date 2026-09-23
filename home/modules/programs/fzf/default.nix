{
  config,
  pkgs,
  lib,
  localLib,
  fzf-wrapped,
  ...
}:
let
  fzfPkg = fzf-wrapped.lib.mkFzf {
    inherit pkgs lib;
    renderCliFlags = localLib.wrapped.cliFlags.render;

    colors = config.lib.stylix.colors.withHashtag;
    histFile = config.programs.zsh.history.path;
  };
in
{
  home.packages = [ fzfPkg ];

  programs.bat.enable = true;
  programs.fd.enable = true;
  programs.ripgrep.enable = true;

  programs.bash.initExtra = "source ${fzfPkg}/share/fzf-shell/fzf.sh";

  # fzf.zsh (ZLE widgets/bindkey) is zsh-only, so it isn't sourced into bash.
  programs.zsh.initContent = ''
    source ${fzfPkg}/share/fzf-shell/fzf.sh
    source ${fzfPkg}/share/fzf-shell/fzf.zsh
  '';
}
