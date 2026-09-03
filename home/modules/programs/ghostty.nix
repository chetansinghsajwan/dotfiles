{ pkgs, ... }:
{
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty;

    settings = {
      config-file = "?config-local";
      window-width = 110;
      window-height = 25;
      window-decoration = "none";
      window-padding-x = 8;
      window-padding-y = 8;
    };
  };
}
