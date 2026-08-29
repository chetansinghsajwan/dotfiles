{
  pkgs,
  lib,
  isLinux ? false,
  ...
}@args:
let
  cfgOverrides = args.cfgOverrides or { };
  cfg = import ../config {
    inherit lib;
    overrides = cfgOverrides;
  };
  inherit (cfg) theme;
in
{
  stylix.enable = true;
  stylix.polarity = "dark";
  stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/onedark.yaml";

  stylix.fonts = {
    monospace = {
      package = pkgs.jetbrains-mono;
      name = "JetBrains Mono";
    };
    sansSerif = {
      package = pkgs.poppins;
      name = theme.fonts.sans;
    };
    serif = {
      package = pkgs.poppins;
      name = theme.fonts.sans;
    };
    sizes = {
      applications = theme.fonts.size;
      terminal = 15;
      desktop = theme.fonts.size;
      popups = theme.fonts.size;
    };
  };

  stylix.opacity.terminal = 0.95;
  stylix.cursor.name = "Adwaita";
  stylix.cursor.package = pkgs.adwaita-icon-theme;
  stylix.cursor.size = 24;

  stylix.targets = lib.mkIf isLinux {
    gnome.enable = true;
    gtk.enable = true;
    firefox.profileNames = [ "default" ];
  };
}
