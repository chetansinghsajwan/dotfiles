# config.colors -> config.colorArgs (fzf's --color argument), ported
# from stylix's own fzf target (modules/fzf/hm.nix), since wrapping fzf
# via nix-wrapper-modules bypasses `programs.fzf` and so never runs
# Stylix's target for it. Left at fzf's own defaults (null) when
# `colors` (see module.nix's options.colors) is null.
#
# bg/bg+ are pinned to "-1" (terminal default) rather than themed:
# stylix's own fzf target paints them as solid theme colors, which
# blocks the terminal's transparency/acrylic for the popup.
{ config, ... }:
{
  config.colorArgs =
    if config.colors == null then
      null
    else
      with config.colors;
      "bg:-1,bg+:-1,fg:${base04},fg+:${base06},header:${base0D},hl:${base0D},hl+:${base0D},info:${base0A},marker:${base0C},pointer:${base0C},prompt:${base0A},spinner:${base0C}";
}
