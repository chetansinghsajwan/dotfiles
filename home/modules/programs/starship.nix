{ config, ... }: {
  programs.starship = {
    enable = config.dotfiles.shell.theme == "starship";
    enableZshIntegration = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableNushellIntegration = true;
  };
}
