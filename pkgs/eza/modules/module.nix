# nix-wrapper-modules doesn't ship a native eza wrapper module, so this
# bakes this repo's own eza customization directly into the wrapped
# binary via the generic makeWrapper mechanism (`wlib.modules.default`).
{
  lib,
  pkgs,
  wlib,
  ...
}:
{
  imports = [ wlib.modules.default ];

  config = {
    package = lib.mkDefault pkgs.eza;

    flags = {
      "--git" = true;
      "--icons" = "always";
    };
  };
}
