# colors -> fzf's `--color` argument, ported from stylix's own fzf target
# (modules/fzf/hm.nix), since wrapping fzf via nix-wrapper-modules bypasses
# `programs.fzf` and so never runs Stylix's target for it.
#
# `colors`: a base16 palette as { base00 = "#hex"; ...; }
# (e.g. `config.lib.stylix.colors.withHashtag`), or null to leave fzf's
# colors at their own defaults.
#
# bg/bg+ are pinned to "-1" (terminal default) rather than themed: stylix's
# own fzf target paints them as solid theme colors, which blocks the
# terminal's transparency/acrylic for the popup.
colors:
if colors == null then
  null
else
  with colors;
  "bg:-1,bg+:-1,fg:${base04},fg+:${base06},header:${base0D},hl:${base0D},hl+:${base0D},info:${base0A},marker:${base0C},pointer:${base0C},prompt:${base0A},spinner:${base0C}"
