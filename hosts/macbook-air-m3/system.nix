{ ... }:
{
  imports = [
    ../../config
    ../shared.nix
  ];

  dotfiles.user.username = "kyutoo";
  dotfiles.system.isDarwin = true;
  system.primaryUser = "kyutoo";
  system.stateVersion = 6;
}
