{
  config,
  lib,
  pkgs,
  ...
}:
let
  theme = config.dotfiles.theme;
  rawFontScale = theme.fonts.rawFontScale;
  isLinux = config.dotfiles.system.isLinux;
  enableGui = config.dotfiles.features.gui;
  enableGnome = config.dotfiles.desktop.gnome.enable;
in
{
  fonts.fontconfig.enable = true;

  stylix = {
    enable = true;
    polarity = "dark";
    image = theme.wallpaper;
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

    targets = {
      # These write settings via dconf, which requires a running GNOME/GTK
      # session bus. Only enable them when a GUI is actually in use, or
      # activation fails on headless setups (e.g. WSL) with a dbus error.
      gtk.enable = enableGui;
      gnome.enable = enableGnome;
      gnome-text-editor.enable = enableGnome;
      eog.enable = enableGnome;

      ghostty = {
        fonts.override = {
          sizes = {
            terminal = config.stylix.fonts.sizes.terminal * rawFontScale;
          };
        };
      };

      neovim.transparentBackground = {
        main = true;
        signColumn = true;
        numberLine = true;
      };

      helix.transparent = true;

      zed = {
        fonts.override = {
          sizes = {
            applications = config.stylix.fonts.sizes.applications * rawFontScale * .92;
            terminal = config.stylix.fonts.sizes.terminal * rawFontScale;
            desktop = config.stylix.fonts.sizes.desktop * rawFontScale;
            popups = config.stylix.fonts.sizes.popups * rawFontScale;
          };
        };
      };
    };
  }
  // lib.optionalAttrs isLinux {
    cursor.name = theme.cursor.theme.name;
    cursor.package = theme.cursor.theme.pkg;
    cursor.size = theme.cursor.theme.size;
  };
}
