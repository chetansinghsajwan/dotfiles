{ ... }:
{
  imports = [
    ../../config
    ../shared.nix
  ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  dotfiles.user.username = "kyutoo";
  dotfiles.system.isDarwin = true;
  system.primaryUser = "kyutoo";
  system.stateVersion = 6;
}
