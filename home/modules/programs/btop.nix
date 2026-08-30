# home/modules/programs/btop.nix
_: {
  programs.btop = {
    settings = {
      vim_keys = true;
      theme_background = false;
    };
  };
}
