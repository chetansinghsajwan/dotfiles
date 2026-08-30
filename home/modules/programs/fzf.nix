{ config, ... }: {
  programs.fzf = {
    enableZshIntegration = config.dotfiles.shell.program == "zsh";
    enableFishIntegration = config.dotfiles.shell.program == "fish";
  };
}
