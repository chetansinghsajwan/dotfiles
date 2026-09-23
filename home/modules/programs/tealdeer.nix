{
  pkgs,
  lib,
  tealdeer-wrapped,
  ...
}:
{
  home.packages = [
    (tealdeer-wrapped.lib.mkTealdeer {
      inherit pkgs lib;
      settings.updates.auto_update = true;
    })
  ];
}
