{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.programs.zed-editor.enable {
    home.packages = with pkgs; [
      llvmPackages_19.clang-tools
    ];

    programs.zed-editor = {
      userSettings = {
        lsp = {
          clangd = {
            binary.path = "${pkgs.llvmPackages_19.clang-tools}/bin/clangd";
            arguments = [ "--compile-commands-dir=/build" ];
          };
        };

        languages = {
          "C++".language_servers = [ "clangd" ];
        };
      };
    };
  };
}
