{ config, lib, ... }:
{
    config = lib.mkIf config.dotfiles.programs.docker.enable {
        home.file = {
            ".config/docker-pick/docker.sh".source = ./docker.sh;
            ".config/docker-pick/docker.zsh".source = ./docker.zsh;
        };

        programs.bash.initExtra = ''
            source ~/.config/docker-pick/docker.sh
        '';
        # docker.zsh (ZLE widgets/bindkey) is zsh-only, so it isn't sourced into bash.
        programs.zsh.initContent = ''
            source ~/.config/docker-pick/docker.sh
            source ~/.config/docker-pick/docker.zsh
        '';

    };
}
