{ pkgs, ... }:
{
  imports = [
    ../programs/git.nix
    ../programs/vscode
  ];

  home.packages = with pkgs; [
    gh
    cmake
    lldb
    clang
    llvmPackages_18.clang-tools
  ];
}
