{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.programs.zed-editor.enable {
    home.packages = with pkgs; [
      nixd
    ];

    programs.zed-editor = {
      extensions = [
        "nix"
      ];

      userSettings = {
        lsp = {
          nil.settings.formatting.command = [ "nixpkgs-fmt" ];
        };

        languages = {
          Nix.language_servers = [ "nil" ];
        };
      };
    };
  };
}
