{ lib, ... }:
{
  imports = [
    ../../config
    ../shared.nix
    ./system.nix
  ];

  dotfiles.features.gui = lib.mkForce false;
  dotfiles.desktop.gnome.enable = lib.mkForce false;
  dotfiles.desktop.hyprland.enable = lib.mkForce false;
  dotfiles.system.isWsl = lib.mkForce true;
  dotfiles.system.isLinux = true;
  dotfiles.system.extraGroups = [ "wheel" ];

  wsl.enable = true;
  wsl.defaultUser = config.dotfiles.user.username;

  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_IN";

  networking.hostName = "nixos-wsl";
  system.stateVersion = "23.05";
}
