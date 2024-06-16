{ ... }:
{
  programs.neovim = {
    enable = true;

    extraConfig = ''
      nnoremap i <Up>
      nnoremap k <Down>
      nnoremap j <Left>
      nnoremap l <Right>
      nnoremap h <insert>

      vnoremap i <Up>
      vnoremap k <Down>
      vnoremap j <Left>
      vnoremap l <Right>
      vnoremap h <insert>
    '';
  };
}
