# home/modules/programs/lazygit.nix
{
  config,
  pkgs,
  lib,
  lazygit-wrapped,
  ...
}:
{
  home.packages = [
    (lazygit-wrapped.lib.mkLazygit {
      inherit pkgs lib;
      colors = config.lib.stylix.colors.withHashtag;
    })
  ];
}
