{
  config,
  pkgs,
  ...
}:
let
  theme = config.dotfiles.theme;
in
{
  stylix = {
    enable = true;
    autoEnable = false;
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/ayu-dark.yaml";

    fonts = {
      monospace = {
        package = pkgs.nerdfonts.jetbrains-mono;
        name = theme.fonts.mono;
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

    opacity.terminal = 0.95;
    cursor.name = "Adwaita";
    cursor.package = pkgs.adwaita-icon-theme;
    cursor.size = 24;

    targets = {
      gnome.enable = config.dotfiles.desktop.gnome.enable;
      gtk.enable = config.dotfiles.desktop.gnome.enable;
      firefox.enable = config.programs.firefox.enable;
      firefox.profileNames = [ "default" ];
    };
  };
}
