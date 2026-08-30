{ config, ... }: {
    programs.fish = {
        enable = config.dotfiles.shell.program == "fish";
    };
}