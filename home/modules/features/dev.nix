{
  config,
  pkgs,
  lib,
  ...
}:
let
  enableDev = config.dotfiles.features.dev;
  enableGui = config.dotfiles.features.gui;
in
{
  config = lib.mkIf enableDev {
    home.packages = with pkgs; [
      cmake
      lldb
      clang
      llvmPackages_18.clang-tools
    ];

    programs = {
      vscode.enable = enableGui;
    };
  };
}
