{ config, ... }:
{
    # Shell pickers (history, files, cd, text search, ...) on `pick`, the shared
    # picker (home/programs/pick). The git, docker, nixpkgs and clipboard modules
    # add their own pickers the same way.
    #
    # bat and ripgrep are used by the pickers' previews.
    programs.bat.enable = true;
    programs.ripgrep.enable = true;

    home.file = {
        # fh's history file path is baked in from the zsh config below instead
        # of read from $HISTFILE at call time, so it can't silently fall back
        # to a stale/wrong file in a context where $HISTFILE isn't set.
        ".config/pick-shell/pickers.sh".text =
            builtins.replaceStrings [ "@histfile@" ] [ config.programs.zsh.history.path ]
                (builtins.readFile ./pickers.sh);
        ".config/pick-shell/pickers.zsh".source = ./pickers.zsh;
    };

    programs.bash.initExtra = "source ~/.config/pick-shell/pickers.sh";

    # pickers.zsh (ZLE widgets/bindkey) is zsh-only, so it isn't sourced into bash.
    programs.zsh.initContent = ''
        source ~/.config/pick-shell/pickers.sh
        source ~/.config/pick-shell/pickers.zsh
    '';
}
