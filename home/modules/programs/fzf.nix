{ config, ... }: {
  programs.fzf = {
    enable = true;
    enableZshIntegration = config.dotfiles.shell.program == "zsh";
    enableFishIntegration = config.dotfiles.shell.program == "fish";
  };
}