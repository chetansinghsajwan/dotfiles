{ config, ... }: {
    programs.zellij = {
        enableBashIntegration = config.dotfiles.shell.program == "bash";
        enableZshIntegration = config.dotfiles.shell.program == "zsh";
        enableFishIntegration = config.dotfiles.shell.program == "fish";
        exitShellOnExit = true;

        # Default tab mode binds k -> previous tab, j -> next tab; reverse them.
        extraConfig = ''
            keybinds {
                tab {
                    bind "j" { GoToPreviousTab; }
                    bind "k" { GoToNextTab; }
                }
            }
        '';
    };
}
