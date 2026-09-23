{
  config,
  pkgs,
  lib,
  localLib,
  zellij-wrapped,
  ...
}:
{
  home.packages = [
    (zellij-wrapped.lib.mkZellij {
      inherit pkgs lib;
      inherit (localLib.wrapped.base16) substituteTemplate;
      inherit (localLib.wrapped.kdl) renderDocument;

      colors = config.lib.stylix.colors.withHashtag;
    })
  ];

  home.shellAliases = {
    z = "zellij";
  };
}
