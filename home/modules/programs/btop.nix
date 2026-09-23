# home/modules/programs/btop.nix
{
  config,
  pkgs,
  lib,
  btop-wrapped,
  ...
}:
{
  home.packages = [
    (btop-wrapped.lib.mkBtop {
      inherit pkgs lib;

      colors = config.lib.stylix.colors.withHashtag;

      settings = {
        vim_keys = true;
        theme_background = false;
      };
    })
  ];
}
