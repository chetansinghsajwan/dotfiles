{
  config,
  localLib,
  ...
}:
localLib.mkToggleModule config "docker" {
  home.file = {
    ".config/docker-fzf/docker.sh".source = ./docker.sh;
    ".config/docker-fzf/docker.zsh".source = ./docker.zsh;
  };

  programs.bash.initExtra = ''
    source ~/.config/docker-fzf/docker.sh
  '';
  # docker.zsh (ZLE widgets/bindkey) is zsh-only, so it isn't sourced into bash.
  programs.zsh.initContent = ''
    source ~/.config/docker-fzf/docker.sh
    source ~/.config/docker-fzf/docker.zsh
  '';

  programs.fzf.enable = true;
}
