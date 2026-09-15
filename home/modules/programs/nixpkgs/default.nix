{
  config,
  pkgs,
  localLib,
  ...
}:
localLib.mkToggleModule config "nixpkgs" {
  home.file = {
    ".config/nixpkgs-fzf/nixpkgs.sh".source = ./nixpkgs.sh;
    ".config/nixpkgs-fzf/nixpkgs.zsh".source = ./nixpkgs.zsh;
  };

  home.packages = [ pkgs.jq ];

  programs.bash.initExtra = ''
    source ~/.config/nixpkgs-fzf/nixpkgs.sh
  '';
  # nixpkgs.zsh (ZLE widgets/bindkey) is zsh-only, so it isn't sourced into bash.
  programs.zsh.initContent = ''
    source ~/.config/nixpkgs-fzf/nixpkgs.sh
    source ~/.config/nixpkgs-fzf/nixpkgs.zsh
  '';

  programs.fzf.enable = true;
}
