{ config, lib, ... }: {
  config = lib.mkIf config.programs.neovim.enable {
    programs.neovim = {
      withRuby = false;
      withPython3 = false;
      initLua = ''
        vim.o.tabstop = 4
        vim.o.expandtab = true
        vim.o.softtabstop = 4
        vim.o.shiftwidth = 4
      '';
    };

    home.shellAliases.nv = "nvim";
  };
}
