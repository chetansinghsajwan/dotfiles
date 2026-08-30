{
  config,
  pkgs,
  localLib,
  ...
}:
localLib.mkToggleModule config "libreoffice" {
  home.packages = [ pkgs.libreoffice ];
}
