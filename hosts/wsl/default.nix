{
  nixpkgs,
  nur,
  home-manager,
  stylix,
  nixos-wsl,
  localLib,
  helix-wrapped,
  btop-wrapped,
  lazygit-wrapped,
  zellij-wrapped,
  ...
}:
let
  inherit (nixpkgs) lib;
in
nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    nixos-wsl.nixosModules.default
    ./system.nix

    home-manager.nixosModules.home-manager
    (localLib.mkHomeManagerModule {
      username = "chetansinghsajwan";
      extraSpecialArgs = {
        inherit
          nur
          localLib
          helix-wrapped
          btop-wrapped
          lazygit-wrapped
          zellij-wrapped
          ;
      };
      imports = [
        ../../home/home.nix
        stylix.homeModules.stylix

        {
          dotfiles.features.gui = lib.mkForce false;
          dotfiles.desktop.gnome.enable = lib.mkForce false;
          dotfiles.desktop.hyprland.enable = lib.mkForce false;
          dotfiles.system.isWsl = lib.mkForce true;
          dotfiles.system.isLinux = lib.mkForce true;
        }

        ../../local.nix
      ];
    })
  ];
}
