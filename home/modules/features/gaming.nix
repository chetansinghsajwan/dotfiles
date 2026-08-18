{ pkgs, ... }:
{
  home.packages = with pkgs; [
    bottles
    proton-vpn-cli
    protonvpn-gui
  ];
}
