# home/modules/programs/btop.nix
_: {
  programs.btop = {
    enable = true;
    settings = {
      vim_keys = true;
      theme_background = false;
    };
  };
}