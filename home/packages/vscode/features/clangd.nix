{ pkgs, ... }:
{
  home.packages = with pkgs; [
    clang-tools_18
  ];

  programs.vscode = {
    extensions = with pkgs.vscode-extensions; [
      llvm-vs-code-extensions.vscode-clangd
    ];

    userSettings = {
      clangd.path = "${pkgs.clang-tools_18}/bin/clangd";
      clangd.checkUpdates = false;
      clangd.enableCodeCompletion = true;
      clangd.onConfigChanged = "restart";
      clangd.restartAfterCrash = true;
    };
  };
}
