# config.colors -> config.settings.gui.theme, ported from stylix's own
# lazygit target (modules/lazygit/hm.nix), since wrapping lazygit via
# nix-wrapper-modules bypasses `programs.lazygit` and so never runs
# Stylix's target for it. Left at lazygit's own defaults ({ }) when
# `colors` (see module.nix's options.colors) is null.
{ config, ... }:
{
  config.settings.gui.theme =
    if config.colors == null then
      { }
    else
      with config.colors;
      {
        activeBorderColor = [
          base0D
          "bold"
        ];
        inactiveBorderColor = [ base03 ];
        searchingActiveBorderColor = [
          base04
          "bold"
        ];
        optionsTextColor = [ base06 ];
        selectedLineBgColor = [ base03 ];
        cherryPickedCommitBgColor = [ base02 ];
        cherryPickedCommitFgColor = [ base03 ];
        unstagedChangesColor = [ base08 ];
        defaultFgColor = [ base05 ];
      };
}
