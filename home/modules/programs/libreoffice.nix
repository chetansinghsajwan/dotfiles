{
  config,
  pkgs,
  llib,
  ...
}:
llib.mkToggleModule config "libreoffice" {
  home.packages = [ pkgs.libreoffice ];
}
