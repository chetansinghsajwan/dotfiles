{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./kanata.nix
    ./system.nix
    ./user.nix
  ];
}
