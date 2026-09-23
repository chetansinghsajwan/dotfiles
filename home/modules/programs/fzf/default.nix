{
  config,
  pkgs,
  lib,
  localLib,
  fzf-wrapped,
  ...
}:
let
  fzfPkg = fzf-wrapped.lib.mkFzf {
    inherit pkgs lib;
    renderCliFlags = localLib.wrapped.cliFlags.render;

    colors = config.lib.stylix.colors.withHashtag;

    # stylix's fzf mapping paints bg/bg+ as solid theme colors, which
    # blocks the terminal's transparency/acrylic for the popup. Override
    # just those two to fzf's "-1" — terminal default color — so the
    # popup blends in like the rest of the terminal, while keeping every
    # other themed color as-is.
    colorOverrides = {
      bg = "-1";
      "bg+" = "-1";
    };

    histFile = config.programs.zsh.history.path;

    settings = {
      popup = "90%";
      border = "rounded";
      layout = "reverse";
      margin = 1;
      padding = 1;
      "preview-window" = "right:60%:noborder";
      bind = [
        "ctrl-a:select-all"
        "alt-k:preview-half-page-up"
        "alt-j:preview-half-page-down"
        "ctrl-/:toggle-preview"
      ];
    };
  };
in
{
  home.packages = [ fzfPkg ];

  programs.bat.enable = true;
  programs.fd.enable = true;
  programs.ripgrep.enable = true;

  programs.bash.initExtra = "source ${fzfPkg}/share/fzf-shell/fzf.sh";

  # fzf.zsh (ZLE widgets/bindkey) is zsh-only, so it isn't sourced into bash.
  programs.zsh.initContent = ''
    source ${fzfPkg}/share/fzf-shell/fzf.sh
    source ${fzfPkg}/share/fzf-shell/fzf.zsh
  '';
}
