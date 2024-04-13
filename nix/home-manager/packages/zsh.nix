{ pkgs, ... }:
{
    programs.zsh = {
        enable = true;
        enableCompletion = true;
        enableAutosuggestions = true;
        syntaxHighlighting.enable = true;

        oh-my-zsh = {
            enable = true;
            plugins = [ "git" "thefuck" ];
            theme = "random";
        };
    };
}
