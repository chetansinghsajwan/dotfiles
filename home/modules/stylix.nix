{
  config,
  pkgs,
  ...
}:
let
  theme = config.dotfiles.theme;
in
{
  fonts.fontconfig.enable = true;

  stylix = {
    enable = true;
    autoEnable = false;
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/${theme.name}.yaml";

    fonts = {
      monospace = {
        package = theme.fonts.mono.pkg;
        name = theme.fonts.mono.name;
      };
      sansSerif = {
        package = theme.fonts.sans.pkg;
        name = theme.fonts.sans.name;
      };
      serif = {
        package = theme.fonts.serif.pkg;
        name = theme.fonts.serif.name;
      };
      sizes = {
        applications = theme.fonts.sizes.applications;
        terminal = theme.fonts.sizes.terminal;
        desktop = theme.fonts.sizes.desktop;
        popups = theme.fonts.sizes.popups;
      };
    };

    opacity.terminal = 0.95;
    cursor.name = theme.cursor.theme.name;
    cursor.package = theme.cursor.theme.pkg;
    cursor.size = theme.cursor.theme.size;

    targets = {
      gnome.enable = config.dotfiles.desktop.gnome.enable;
      gtk.enable = config.dotfiles.desktop.gnome.enable;
      firefox.enable = config.programs.firefox.enable;
      firefox.profileNames = [ "default" ];
      ghostty.enable = config.programs.ghostty.enable;
      vscode.enable = config.programs.vscode.enable;
    };
  };
}
