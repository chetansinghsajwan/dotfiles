{ config, ... }:
{
  imports = [
    ../../config
    ../shared.nix
    ../../local.nix
  ];

  dotfiles.system.isDarwin = true;
  system.stateVersion = config.dotfiles.system.stateVersion.darwin;
}
