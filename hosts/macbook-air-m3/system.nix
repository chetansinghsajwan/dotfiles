{ ... }:
{
  imports = [
    ../../config
    ../shared.nix
    ../../local.nix
  ];

  dotfiles.system.isDarwin = true;
  system.stateVersion = 6;
}
