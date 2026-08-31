{ config, ... }: {
  wsl.enable = true;
  wsl.defaultUser = config.dotfiles.user.username;

  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_IN";

  networking.hostName = "nixos-wsl";
  system.stateVersion = "23.05";
}
