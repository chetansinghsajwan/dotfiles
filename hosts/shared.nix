{ config, pkgs, ... }:
let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
in
{
  users.users.${config.dotfiles.user.username} = {
    home =
      if isDarwin then
        "/Users/${config.dotfiles.user.homeDir}"
      else
        "/home/${config.dotfiles.user.homeDir}";

    shell = pkgs.${config.dotfiles.shell.program};
    isNormalUser = true;
    extraGroups = config.dotfiles.system.extraGroups;
  };

  programs = {
    ${config.dotfiles.shell.program}.enable = true;
    nix-ld.enable = true;
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.enable = true;
  nix.optimise.automatic = true;
  nixpkgs.config.allowUnfree = true;
}
