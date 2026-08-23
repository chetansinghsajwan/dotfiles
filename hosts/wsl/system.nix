{ pkgs, ... }:
{
  wsl.enable = true;
  wsl.defaultUser = "chetansinghsajwan";

  nix.optimise.automatic = true;

  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_IN";

  networking.hostName = "nixos-wsl";
  system.stateVersion = "23.05";
}
