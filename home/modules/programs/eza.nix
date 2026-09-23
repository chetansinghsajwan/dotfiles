{
  pkgs,
  lib,
  localLib,
  eza-wrapped,
  ...
}:
{
  home.packages = [
    (eza-wrapped.lib.mkEza {
      inherit pkgs lib;
      renderCliFlags = localLib.wrapped.cliFlags.render;
    })
  ];

  # Was programs.eza.enableZshIntegration's generated aliases; "eza" itself
  # no longer needs its own alias since the wrapped binary already bakes in
  # the flags above.
  home.shellAliases = {
    la = "eza -a";
    ll = "eza -l";
    lla = "eza -la";
    ls = "eza";
    lt = "eza --tree";
  };
}
