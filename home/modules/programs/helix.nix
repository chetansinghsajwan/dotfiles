{
  config,
  lib,
  pkgs,
  localLib,
  helix-wrapped,
  ...
}:
let
  editor = config.dotfiles.editor;
in
{
  home.packages = [
    (helix-wrapped.lib.mkHelix {
      inherit pkgs lib;
      inherit (localLib.wrapped.base16) substituteTemplate;

      colors = config.lib.stylix.colors.withHashtag;

      # The rest of helix's config is baked into pkgs/helix itself; only
      # these four come from config.dotfiles.editor.*, which that flake
      # has no way to see.
      settings.editor = {
        scroll-lines = editor.scroll_lines;
        line-number = editor.line_number;
        text-width = editor.text_width;
        inherit (editor) rulers;
      };
    })
  ];

  # Was programs.helix.defaultEditor = true.
  home.sessionVariables = {
    EDITOR = "hx";
    VISUAL = "hx";
  };
}
