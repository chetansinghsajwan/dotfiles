# This repo's own zellij customization plus nix-wrapper-modules' generic
# wrapper mechanism (wrapper-module.nix, since nix-wrapper-modules ships
# no native zellij module) - so this one file is the complete zellij
# wrapper, and callers only ever need to reference it, not also list
# wrapper-module.nix separately. Theming is this module's own
# responsibility end to end: `colors` defaults to this repo's own
# default base16 theme, so a standalone build is themed out of the box
# with no outer config needed at all. Whatever imports this (see
# flake.nix's `homeModules.default`) may still override `colors` with a
# live palette (e.g. Stylix's) when one is available.
{
  config,
  lib,
  ...
}:
{
  imports = [
    ./wrapper-module.nix

    # Purely so `colors` below can default to config.dotfiles.theme.colors
    # - the same config/default.nix option this repo's home-manager hosts
    # already get, just merged into this wrapper module's own isolated
    # evalModules instead of home-manager's. lib/config are already
    # shared module args, so this needs no separate evalModules call or
    # specialArgs threading.
    ../../../config

    # Sets config.themes.stylix and adds a `theme "stylix"` line to
    # config.configKdl, from config.colors.
    ./theme.nix
  ];

  options.colors = lib.mkOption {
    type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
    default = config.dotfiles.theme.colors;
    defaultText = lib.literalExpression "config.dotfiles.theme.colors";
    description = ''
      base16 palette as { base00 = "#hex"; ...; base0F = "#hex"; }, e.g.
      `config.lib.stylix.colors.withHashtag`. Defaults to this repo's own
      config.dotfiles.theme.colors; set to null to leave zellij unthemed
      (its own defaults) instead.
    '';
  };

  config = {
    # Default tab mode groups h/Left/Up/k -> previous tab, l/Right/Down/j ->
    # next tab. jk is dropped entirely (kanata handles that now); Up/Down are
    # reversed relative to the default so Up goes to the next tab.
    #
    # GoToNextTab/GoToPreviousTab always wrap around at the ends; there's no
    # config option to stop that as of zellij 0.45.0. A `tab_cycle_wrap false`
    # option was proposed upstream but is unmerged: see
    # https://github.com/zellij-org/zellij/pull/4815. Revisit once it lands.
    configKdl = ''
      keybinds {
          // Default tab mode binds k -> previous tab, j -> next tab; reverse them.
          tab {
              unbind "j" "k"
              bind "Up" { GoToNextTab; }
              bind "Down" { GoToPreviousTab; }
          }

          // Ctrl+/ avoids colliding with typing a literal "?" in a pane.
          shared_except "locked" {
              bind "Ctrl /" {
                  LaunchOrFocusPlugin "file:~/zellij-plugins/zellij_forgot.wasm" {
                      floating true
                  }
              }
          }
      }
    '';

    # Compact bar merges the tab-bar and status-bar into a single line at the
    # top, with a blank borderless row inserted after it so content doesn't
    # sit flush against it.
    layouts.default = ''
      layout {
          pane size=1 borderless=true {
              plugin location="compact-bar"
          }
          pane
      }
    '';
  };
}
