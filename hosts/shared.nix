{
  config,
  lib,
  pkgs,
  ...
}:
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
  }
  // lib.optionalAttrs isLinux {
    isNormalUser = true;
    extraGroups = config.dotfiles.system.extraGroups;
  };

  programs = {
    ${config.dotfiles.shell.program}.enable = true;
  }
  // (
    if isLinux then
      {
        nix-ld.enable = true;
      }
    else
      { }
  );

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.enable = isLinux;
  nix.optimise.automatic = isLinux;
  nixpkgs.config.allowUnfree = true;
}
