{ config, ... }:
{
  imports = [
    ../../config
    ../shared.nix
    ../locale.nix
    ../../local.nix
  ];

  dotfiles = {
    features.gui = false;
    system = {
      isLinux = true;
      isWsl = true;
    };
  };

  wsl.enable = true;
  wsl.defaultUser = config.dotfiles.user.username;

  networking.hostName = "nixos-wsl";
  system.stateVersion = "23.05";
}
