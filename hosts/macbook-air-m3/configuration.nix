{ pkgs, ... }:
{
  # Determinate Nix manages the installation; disable nix-darwin's Nix management
  nix.enable = false;

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  users.users.kyutoo = {
    home = "/Users/kyutoo";
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
  environment.systemPackages = with pkgs; [ git ];

  system.primaryUser = "kyutoo";
  system.stateVersion = 6;
}
