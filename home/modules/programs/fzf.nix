{ config, ... }: {
  programs.fzf = {
    enableBashIntegration = config.dotfiles.shell.program == "bash";
    enableZshIntegration = config.dotfiles.shell.program == "zsh";
    enableFishIntegration = config.dotfiles.shell.program == "fish";
    enableNushellIntegration = config.dotfiles.shell.program == "nushell";

    defaultOptions = [
      "--height 40%"
      "--multi"
      "--cycle"
      "--scheme path"
    ];

    fileWidgetOptions = [
      "--preview 'bat --color=always --line-range :50 {} 2>/dev/null || ls -lah {}'"
      "--bind 'ctrl-d:preview-page-down,ctrl-u:preview-page-up'"
      "--bind 'ctrl-/:toggle-preview'"
    ];

    changeDirWidgetOptions = [
      "--preview 'tree -C {} 2>/dev/null | head -100'"
    ];

    historyWidgetOptions = [
      "--preview 'echo {}'"
      "--preview-window down:3:wrap"
      "--tiebreak=index"         # on equal score, prefer most recent (bottom of history)
      "--no-sort"                # preserve chronological order fzf receives from shell
    ];
  };

  programs.bat.enable = config.programs.fzf.enable;
}