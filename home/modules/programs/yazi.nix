{
  config,
  lib,
  pkgs,
  localLib,
  yazi-wrapped,
  ...
}:
let
  yaziPkg = yazi-wrapped.lib.mkYazi {
    inherit pkgs lib;
    inherit (localLib.wrapped.base16) substituteTemplate;

    colors = config.lib.stylix.colors.withHashtag;

    # bat already has stylix's base16 -> syntect .tmTheme conversion
    # (via its own still-real programs.bat module), so reuse that file
    # instead of reimplementing the conversion here.
    syntectTheme = config.programs.bat.themes."base16-stylix".src;
  };
in
{
  home.packages = [ yaziPkg ];

  # cd-on-exit wrapper (was programs.yazi.shellWrapperName = "y" +
  # enableZshIntegration/enableFishIntegration/enableNushellIntegration);
  # the actual function bodies now ship inside yaziPkg itself.
  programs.zsh.initContent = lib.mkIf (
    config.dotfiles.shell.program == "zsh"
  ) "source ${yaziPkg}/share/yazi-shell/y.zsh";

  programs.fish.interactiveShellInit = lib.mkIf (
    config.dotfiles.shell.program == "fish"
  ) "source ${yaziPkg}/share/yazi-shell/y.fish";

  programs.nushell.extraConfig = lib.mkIf (
    config.dotfiles.shell.program == "nushell"
  ) "source ${yaziPkg}/share/yazi-shell/y.nu";
}
