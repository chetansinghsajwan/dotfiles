{ pkgs, ... }:
{
  home.packages = with pkgs; [
    llvmPackages_18.clang-tools
  ];

  programs.vscode = {
    extensions = with pkgs.vscode-extensions; [
      llvm-vs-code-extensions.vscode-clangd
    ];

    userSettings = {
      clangd.path = "${pkgs.llvmPackages_18.clang-tools}/bin/clangd";
      clangd.arguments = [
        "--compile-commands-dir=\${workspaceFolder}/build"
      ];
      clangd.checkUpdates = false;
      clangd.enableCodeCompletion = true;
      clangd.onConfigChanged = "restart";
      clangd.restartAfterCrash = true;
    };
  };
}
