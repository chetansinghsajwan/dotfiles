# config.colors -> zellij's themes/stylix.kdl + a `theme "stylix"`
# activation line in config.kdl, ported from stylix's own zellij target
# (modules/zellij/hm.nix - the exact same base/background/emphasis_0-3
# mapping per UI category), since wrapping zellij via nix-wrapper-modules
# bypasses `programs.zellij` and so never runs Stylix's target for it.
# Left unthemed (zellij's own defaults) when `colors` (see module.nix's
# options.colors) is null.
{ config, lib, ... }:
let
  # KDL is whitespace-insensitive (parses on braces/tokens, not
  # indentation), so this doesn't bother nesting the output prettily.
  mkCategory = name: base: background: emphasis_0: emphasis_1: emphasis_2: emphasis_3: ''
    ${name} {
      base "${base}"
      background "${background}"
      emphasis_0 "${emphasis_0}"
      emphasis_1 "${emphasis_1}"
      emphasis_2 "${emphasis_2}"
      emphasis_3 "${emphasis_3}"
    }
  '';
in
{
  config = lib.mkIf (config.colors != null) (
    with config.colors;
    {
      themes.stylix = ''
        themes {
          default {
      ''
      + mkCategory "text_unselected" base05 base01 base09 base0C base0B base0F
      + mkCategory "text_selected" base05 base04 base09 base0C base0B base0F
      + mkCategory "ribbon_selected" base01 base0E base08 base09 base0F base0D
      + mkCategory "ribbon_unselected" base05 base02 base08 base05 base0D base0F
      + mkCategory "table_title" base0E base00 base09 base0C base0B base0F
      + mkCategory "table_cell_selected" base05 base04 base09 base0C base0B base0F
      + mkCategory "table_cell_unselected" base05 base01 base09 base0C base0B base0F
      + mkCategory "list_selected" base05 base04 base09 base0C base0B base0F
      + mkCategory "list_unselected" base05 base01 base09 base0C base0B base0F
      + mkCategory "frame_selected" base0E base00 base09 base0C base0F base00
      + mkCategory "frame_highlight" base08 base00 base0F base09 base09 base09
      + mkCategory "exit_code_success" base0B base00 base0C base01 base0F base0D
      + mkCategory "exit_code_error" base08 base00 base0A base00 base00 base00
      + ''
        multiplayer_user_colors {
          player_1 "${base0F}"
          player_2 "${base0D}"
          player_3 "${base00}"
          player_4 "${base0A}"
          player_5 "${base0C}"
          player_6 "${base00}"
          player_7 "${base08}"
          player_8 "${base00}"
          player_9 "${base00}"
          player_10 "${base00}"
        }
      ''
      + ''
          }
        }
      '';

      # config.configKdl is `types.lines`, so this concatenates safely
      # alongside module.nix's own keybinds contribution instead of
      # colliding with it (the same mechanism e.g. zsh's own
      # extraInitContent uses to let multiple packages append text).
      configKdl = ''
        theme "stylix"
      '';
    }
  );
}
