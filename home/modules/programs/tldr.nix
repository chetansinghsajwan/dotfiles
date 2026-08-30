{
  config,
  pkgs,
  localLib,
  ...
}:
localLib.mkToggleModule config "tldr" {
  home.packages = with pkgs; [ tlrc ];
}
