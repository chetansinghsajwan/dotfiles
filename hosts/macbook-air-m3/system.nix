{ ... }:
{
  imports = [
    ../../config
    ../shared.nix
    ../../local.nix
  ];

  dotfiles.user.username = "kyutoo";
  dotfiles.system.isDarwin = true;
  system.primaryUser = "kyutoo";
  system.stateVersion = 6;
}
