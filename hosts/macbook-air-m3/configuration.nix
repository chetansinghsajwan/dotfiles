{ pkgs, ... }:
{
  imports = [
    ../../config
    ../shared.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  dotfiles.user.username = "kyutoo";
  system.primaryUser = "kyutoo";
  system.stateVersion = 6;
}
