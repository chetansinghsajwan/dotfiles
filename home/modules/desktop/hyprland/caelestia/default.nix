{
  config,
  lib,
  ...
}@inputs:
let
  caelestia-shell = inputs.caelestia-shell or null;
  enable =
    caelestia-shell != null
    && config.dotfiles.desktop.hyprland.enable
    && config.dotfiles.desktop.hyprland.shell == "caelestia";
  wallpaper = config.dotfiles.theme.wallpaper;
in
{
  imports = lib.optionals (caelestia-shell != null) [
    caelestia-shell.homeManagerModules.default
  ];

  config = lib.optionalAttrs (caelestia-shell != null) (
    lib.mkIf enable {
      programs.caelestia = {
        enable = true;
        cli.enable = true;
        settings = {
          paths.wallpaperDir = "${config.xdg.userDirs.pictures}/wallpapers";
        };
      };

      wayland.windowManager.hyprland = {
        extraConfig = lib.mkAfter ''
          hl.bind(mod .. " + SPACE", hl.dsp.global("caelestia:launcher"))
        '';
      };

      # The active wallpaper/scheme are runtime state (not config), so there's
      # no declarative option for them; keep caelestia in sync with the
      # declared wallpaper by driving its CLI on every activation, same as
      # the FAQ: https://github.com/caelestia-dots/shell#how-do-i-make-my-colour-scheme-change-to-match-my-wallpaper
      home.activation.caelestiaDynamicScheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${lib.getExe' config.programs.caelestia.cli.package "caelestia"} wallpaper -f ${wallpaper}
        run ${lib.getExe' config.programs.caelestia.cli.package "caelestia"} scheme set -n dynamic
      '';
    }
  );
}
