{ pkgs, ... }:
{
  imports = [
    ../programs/git.nix
    ../programs/vscode.nix
    ../programs/neovim.nix
  ];

  home.packages = with pkgs; [
    gh
    nixpkgs-fmt
    cmake
    lldb
    clang
    llvmPackages_18.clang-tools
  ];
}
