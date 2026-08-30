{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.dotfiles.features.gaming {
    home.packages = with pkgs; [
      bottles
      proton-vpn-cli
      protonvpn-gui
    ];
  };
}
