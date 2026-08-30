{
  config,
  pkgs,
  lib,
  ...
}:
let
  enableDev = config.dotfiles.features.dev;
in
{
  config = lib.mkIf enableDev {
    home.packages = with pkgs; [
      cmake
      lldb
      clang
      llvmPackages_18.clang-tools
    ];
  };
}
