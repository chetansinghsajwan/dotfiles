{ config, ... }:
{
  # Plugins (zsh-syntax-highlighting, zsh-autosuggestions) moved to
  # pkgs/zsh's own wrapper - see pkgs/zsh/module.nix.
  programs.zsh.dotDir = "${config.xdg.configHome}/zsh";
}
