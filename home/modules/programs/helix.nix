{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.programs.helix.enable {
    programs.helix = {
      extraPackages = with pkgs; [
        nil
        lua-language-server
        bash-language-server
        marksman
        vscode-langservers-extracted
        yaml-language-server
      ];

      settings = {
        editor = {
          line-number = "relative";
          cursorline = true;
          true-color = true;
          bufferline = "multiple";
          color-modes = true;

          cursor-shape = {
            normal = "block";
            insert = "bar";
            select = "underline";
          };

          indent-guides.render = true;

          statusline = {
            left = [
              "mode"
              "spinner"
              "file-name"
            ];
            center = [ ];
            right = [
              "diagnostics"
              "selections"
              "position"
              "file-encoding"
            ];
          };
        };
      };
    };
  };
}
