{
  config,
  pkgs,
  lib,
  zsh-wrapped,
  ...
}:
{
  # TODO: this only bakes the ZDOTDIR redirect itself (which programs.zsh
  # already achieves via a tiny mutable ~/.zshenv - `source
  # ~/.config/zsh/.zshenv` - so the practical win here is narrow: the
  # wrapped binary keeps working even if that one bootstrap file is ever
  # missing/deleted). The actual dotfiles under ~/.config/zsh are still
  # written by home-manager's own programs.zsh aggregation (every other
  # module's initContent/shellAliases/sessionVariables feeds into it), and
  # stay mutable. A fuller migration - baking that whole tree into the
  # store too - would mean restructuring how every module that currently
  # does programs.zsh.initContent contributes, which is a much bigger,
  # riskier change. Revisit whether that's worth doing later.
  programs.zsh = {
    package = zsh-wrapped.lib.mkZsh { inherit pkgs lib; };

    dotDir = "${config.xdg.configHome}/zsh";

    plugins = [
      {
        name = "syntax-highlighting";
        src = pkgs.zsh-syntax-highlighting;
        file = "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
      }
      {
        name = "autosuggestions";
        src = pkgs.zsh-autosuggestions;
        file = "share/zsh-autosuggestions/zsh-autosuggestions.zsh";
      }
    ];
  };
}
