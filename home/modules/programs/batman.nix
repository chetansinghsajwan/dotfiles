{
  config,
  pkgs,
  localLib,
  ...
}:
localLib.mkToggleModule config "batman" {
  home.packages = with pkgs; [
    bat-extras.batman
  ];

  home.shellAliases = {
    bm = "batman";
  };
}
