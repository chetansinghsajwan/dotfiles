{
  config,
  lib,
  caelestia-shell ? null,
  ...
}:
let
  enable =
    config.dotfiles.desktop.hyprland.enable && config.dotfiles.desktop.hyprland.shell == "caelestia";
in
{
  imports = lib.optionals (caelestia-shell != null) [
    caelestia-shell.homeManagerModules.default
  ];

  config = lib.mkIf enable {
    programs.caelestia = {
      enable = true;
      cli.enable = true;
    };

    wayland.windowManager.hyprland = {
      extraConfig = lib.mkAfter ''
        hl.bind(mod .. " + SPACE", hl.dsp.global("caelestia:launcher"))
      '';
    };
  };
}
