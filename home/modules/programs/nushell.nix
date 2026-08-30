{ config, ... }: {
    programs.nushell = {
        enable = config.dotfiles.shell.program == "nushell";
    };
}