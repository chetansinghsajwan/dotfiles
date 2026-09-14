{ config, lib, ... }: {
  config = lib.mkIf config.programs.fzf.enable {
    programs.bat.enable = true;
    programs.fd.enable = true;
    programs.ripgrep.enable = true;
    programs.zellij.enable = true;

    home.file = {
      ".config/fzf/fzf.sh".source = ./fzf.sh;
      ".config/fzf/fzf.zsh".source = ./fzf.zsh;
    };

    programs.bash.initExtra = "source ~/.config/fzf/fzf.sh";

    # fzf.zsh (ZLE widgets/bindkey) is zsh-only, so it isn't sourced into bash.
    programs.zsh.initContent = ''
      source ~/.config/fzf/fzf.sh
      source ~/.config/fzf/fzf.zsh
    '';

    programs.fzf.defaultOptions = [
      "--popup 90%"
      "--border rounded"
      "--layout reverse"
      "--margin 1"
      "--padding 1"
      "--preview-window right:60%:noborder"
      "--bind ctrl-a:select-all"
      "--bind alt-k:preview-half-page-up"
      "--bind alt-j:preview-half-page-down"
      "--bind ctrl-/:toggle-preview"
    ];
  };
}
