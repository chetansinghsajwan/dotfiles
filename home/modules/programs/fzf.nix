{ config, ... }: {
  programs.fzf = {
    enableBashIntegration = config.dotfiles.shell.program == "bash";
    enableZshIntegration = config.dotfiles.shell.program == "zsh";
    enableFishIntegration = config.dotfiles.shell.program == "fish";

    defaultOptions = [
      "--height 40%"
      "--multi"
      "--cycle"
      "--scheme path"
      "--preview 'bat --color=always --line-range :50 {} 2>/dev/null || ls -lah {}'"
      "--bind 'ctrl-d:preview-page-down,ctrl-u:preview-page-up'"
      "--bind 'ctrl-/:toggle-preview'"
    ];
  };

  programs.bat.enable = true;
}
