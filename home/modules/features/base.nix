{ pkgs, ... }:
{
  imports = [
    # Core shell configuration
    ../shell/default.nix
    ../programs/neovim.nix

    # Utilities
    ../programs/eza.nix
  ];

  home.packages = with pkgs; [
    tree
    curl
    git-lfs
    nixpkgs-fmt
  ];
}
