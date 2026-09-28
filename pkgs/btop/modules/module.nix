# nix-wrapper-modules wrapper module: pulls in nix-wrapper-modules' own
# native btop module plus this repo's customization (settings, theme) on
# top - so this one file is the complete btop wrapper, and callers only
# ever need to reference it, not also list `wrappers.wrapperModules.btop`
# separately. Theming is this module's own responsibility end to end:
# `colors` defaults to this repo's own default base16 theme, so a
# standalone build is themed out of the box with no outer config needed
# at all. Whatever imports this (see flake.nix's `homeModules.default`)
# may still override `colors` with a live palette (e.g. Stylix's) when
# one is available.
{
  config,
  lib,
  wlib,
  ...
}:
{
  imports = [
    wlib.wrapperModules.btop

    # Purely so `colors` below can default to config.dotfiles.theme.colors
    # - the same config/default.nix option this repo's home-manager hosts
    # already get, just merged into this wrapper module's own isolated
    # evalModules instead of home-manager's. lib/config are already
    # shared module args, so this needs no separate evalModules call or
    # specialArgs threading.
    ../../../config

    # Sets config.settings.color_theme/config.themes.stylix from
    # config.colors.
    ./theme.nix
  ];

  options.colors = lib.mkOption {
    type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
    default = config.dotfiles.theme.colors;
    defaultText = lib.literalExpression "config.dotfiles.theme.colors";
    description = ''
      base16 palette as { base00 = "#hex"; ...; base0F = "#hex"; }, e.g.
      `config.lib.stylix.colors.withHashtag`. Defaults to this repo's own
      config.dotfiles.theme.colors; set to null to leave btop unthemed
      (its own defaults) instead.
    '';
  };

  config.settings = {
    vim_keys = true;
    theme_background = false;
  };
}
