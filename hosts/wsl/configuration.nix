{ ... }:
{
  imports = [
    ../../config
    ./system.nix
    ../user.nix
  ];

  dotfiles.features.gui = lib.mkForce false;
  dotfiles.system.extraGroups = [ "wheel" ];
}
