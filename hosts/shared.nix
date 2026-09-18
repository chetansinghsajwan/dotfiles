{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotfiles;
  isLinux = cfg.system.isLinux;
  isDarwin = cfg.system.isDarwin;
in
{
  users.users.${cfg.user.username} = {
    home = if isDarwin then "/Users/${cfg.user.homeDir}" else "/home/${cfg.user.homeDir}";

    shell = pkgs.${cfg.shell.program};
  }
  // lib.optionalAttrs isLinux {
    isNormalUser = true;
    extraGroups = cfg.system.extraGroups;
  };

  programs = {
    ${cfg.shell.program}.enable = true;
  }
  // lib.optionalAttrs isLinux {
    nix-ld.enable = true;
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # nix-darwin manages the Nix install itself, so leave nix.* unmanaged there.
  nix.enable = isLinux;
  nix.optimise.automatic = isLinux;
  nixpkgs.config.allowUnfree = true;

  networking = lib.optionalAttrs isLinux {
    firewall.enable = true;
  };
}
