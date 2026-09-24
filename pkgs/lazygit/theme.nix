# colors -> lazygit gui.theme, ported from stylix's own lazygit target
# (modules/lazygit/hm.nix), since wrapping lazygit via nix-wrapper-modules
# bypasses `programs.lazygit` and so never runs Stylix's target for it.
#
# `colors`: a base16 palette as { base00 = "#hex"; ...; }
# (e.g. `config.lib.stylix.colors.withHashtag`), or null to leave lazygit's
# theme at its own defaults.
colors:
if colors == null then
  { }
else
  with colors;
  {
    gui.theme = {
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
