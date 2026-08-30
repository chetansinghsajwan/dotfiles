{ config, pkgs, ... }:
{
  users.users.${config.dotfiles.user.username} = {
    home = config.dotfiles.user.homeDirectory;
    shell = pkgs.${config.dotfiles.shell.program};
    isNormalUser = true;
    extraGroups = config.dotfiles.system.extraGroups;
  };

  programs.${config.dotfiles.shell.program}.enable = true;
}
