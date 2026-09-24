{
  config,
  pkgs,
  lib,
  ...
}:
let
  clang-tools = pkgs.llvmPackages_19.clang-tools;
in
{
  config = lib.mkIf config.programs.vscode.enable {
    home.packages = [
      clang-tools
    ];

    programs.vscode.profiles.default = {
      extensions = with pkgs.vscode-extensions; [
        llvm-vs-code-extensions.vscode-clangd
      ];

      userSettings = {
        "clangd.path" = "${clang-tools}/bin/clangd";
        "clangd.arguments" = [
          "--compile-commands-dir=\${workspaceFolder}/build"
        ];
        "clangd.checkUpdates" = false;
        "clangd.enableCodeCompletion" = true;
        "clangd.onConfigChanged" = "restart";
        "clangd.restartAfterCrash" = true;
      };
    };
  };
}
