{
  nixpkgs,
  nur,
  home-manager,
  stylix,
  nixos-wsl,
  vscode-extensions,
  localLib,
  ...
}:
let
  inherit (nixpkgs) lib;
in
nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    nixos-wsl.nixosModules.default
    ./configuration.nix

    home-manager.nixosModules.home-manager
    {
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "bak";
      home-manager.extraSpecialArgs = {
        inherit nur vscode-extensions localLib;
      };

      home-manager.users.chetansinghsajwan.imports = [
        ../../home/home.nix
        ../../config
        stylix.homeModules.stylix

        {
          dotfiles.features.gui = lib.mkForce false;
          dotfiles.desktop.gnome.enable = lib.mkForce false;
        }
      ];
    }
  ];
}
