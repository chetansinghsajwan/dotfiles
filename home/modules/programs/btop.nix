# home/modules/programs/btop.nix
{
  config,
  pkgs,
  lib,
  localLib,
  btop-wrapped,
  ...
}:
{
  home.packages = [
    (btop-wrapped.lib.mkBtop {
      inherit pkgs lib;
      inherit (localLib.wrapped.base16) substituteTemplate;

      colors = config.lib.stylix.colors.withHashtag;

      settings = {
        vim_keys = true;
        theme_background = false;
      };
    })
  ];
}
