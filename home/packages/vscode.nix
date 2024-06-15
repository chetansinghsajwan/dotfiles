{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    mutableExtensionsDir = false;

    userSettings = import ./vscode/settings.nix;
    userTasks = import ./vscode/tasks.nix;
    keybindings = import ./vscode/keybindings.nix;
  };

  imports = [
    ./vscode/languages/cpp.nix
    ./vscode/languages/c.nix
    ./vscode/languages/csharp.nix
    ./vscode/languages/md.nix
    ./vscode/languages/html.nix
    ./vscode/languages/json.nix
    ./vscode/languages/nix.nix

    ./vscode/features/clangd.nix
    ./vscode/features/cmake.nix

    ./vscode/themes/material-icons.nix
    ./vscode/themes/one-dark-pro.nix
    ./vscode/themes/github.nix
  ];
}
