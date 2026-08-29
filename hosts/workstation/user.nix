{ config, pkgs, ... }:
{
  users.users.${config.dotfiles.user.username} = {
    home = config.dotfiles.user.homeDirectory;
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = config.dotfiles.system.extraGroups;
  };
}
