{
    config,
    pkgs,
    ...
}: {
    programs.ghostty = {
        package =
            if config.dotfiles.system.isDarwin
            then pkgs.ghostty-bin
            else pkgs.ghostty;

        enableBashIntegration = config.dotfiles.shell.program == "bash";
        enableZshIntegration = config.dotfiles.shell.program == "zsh";
        enableFishIntegration = config.dotfiles.shell.program == "fish";

        settings = {
            config-file = "?config-local";
            window-width = 110;
            window-height = 25;
            window-decoration = "none";
            window-padding-x = 8;
            window-padding-y = 8;
        };
    };
}
