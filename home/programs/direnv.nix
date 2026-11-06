{
    config,
    ...
}:
{
    programs.direnv = {
        enableBashIntegration = config.dotfiles.shell.program == "bash";
        enableZshIntegration = config.dotfiles.shell.program == "zsh";
        enableFishIntegration = config.dotfiles.shell.program == "fish";
        enableNushellIntegration = config.dotfiles.shell.program == "nushell";
        nix-direnv.enable = true;
    };
}
