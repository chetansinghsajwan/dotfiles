{ config, lib, ... }: {
  config = lib.mkIf config.programs.fzf.enable {
    programs.bat.enable = true;
    programs.fd.enable = true;
    programs.ripgrep.enable = true;
    programs.zellij.enable = true;

    home.file = {
      # fh's history file path is baked in from the zsh config below instead
      # of read from $HISTFILE at call time, so it can't silently fall back
      # to a stale/wrong file in a context where $HISTFILE isn't set.
      ".config/fzf/fzf.sh".text =
        builtins.replaceStrings [ "@histfile@" ] [ config.programs.zsh.history.path ]
          (builtins.readFile ./fzf.sh);
      ".config/fzf/fzf.zsh".source = ./fzf.zsh;
    };

    programs.bash.initExtra = "source ~/.config/fzf/fzf.sh";

    # fzf.zsh (ZLE widgets/bindkey) is zsh-only, so it isn't sourced into bash.
    programs.zsh.initContent = ''
      source ~/.config/fzf/fzf.sh
      source ~/.config/fzf/fzf.zsh
    '';

    # stylix's fzf target paints bg/bg+ as solid theme colors, which blocks
    # the terminal's transparency/acrylic for the popup. Override just those
    # two (via stylix's per-target color-override hook) to fzf's "-1" —
    # terminal default color — so the popup blends in like the rest of the
    # terminal, while keeping every other themed color as-is.
    stylix.targets.fzf.colors.override.withHashtag = {
      base00 = "-1";
      base01 = "-1";
    };

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
