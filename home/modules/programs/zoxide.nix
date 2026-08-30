{ config, ... }: {
  programs.zoxide = {
    enableZshIntegration = config.dotfiles.shell.program == "zsh";
    enableFishIntegration = config.dotfiles.shell.program == "fish";
    enableNushellIntegration = config.dotfiles.shell.program == "nushell";
  };
}
