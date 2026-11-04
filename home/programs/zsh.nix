{ config, pkgs, ... }:
{
    programs.zsh = {
        # A time with every command, so the history picker can show when it last ran.
        history.extended = true;

        dotDir = "${config.xdg.configHome}/zsh";

        plugins = [
            {
                name = "syntax-highlighting";
                src = pkgs.zsh-syntax-highlighting;
                file = "share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh";
            }
            {
                name = "autosuggestions";
                src = pkgs.zsh-autosuggestions;
                file = "share/zsh-autosuggestions/zsh-autosuggestions.zsh";
            }
        ];
    };
}
