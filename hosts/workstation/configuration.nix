{ ... }:
{
  imports = [
    ../../config
    ../shared.nix
    ./hardware-configuration.nix
    ./kanata.nix
    ./system.nix
  ];
}
