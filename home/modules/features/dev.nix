{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ../programs/git.nix
    ../programs/vscode
  ];

  config = lib.mkIf config.dotfiles.features.dev {
    home.packages = with pkgs; [
      gh
      cmake
      lldb
      clang
      llvmPackages_18.clang-tools
    ];
  };
}
