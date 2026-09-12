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
in
{
  imports = lib.optionals enable [
    caelestia-shell.homeManagerModules.default
  ];

  config = lib.optionalAttrs enable {
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
