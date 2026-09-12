{ config, ... }: {
    programs.zellij = {
        enableBashIntegration = config.dotfiles.shell.program == "bash";
        enableZshIntegration = config.dotfiles.shell.program == "zsh";
        enableFishIntegration = config.dotfiles.shell.program == "fish";
        exitShellOnExit = true;
    };
}
