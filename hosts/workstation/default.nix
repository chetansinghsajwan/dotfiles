{
  nixpkgs,
  nur,
  home-manager,
  stylix,
  vscode-extensions,
  localLib,
  ...
}:
let
  lib = nixpkgs.lib;
in
nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    ./configuration.nix

    home-manager.nixosModules.home-manager
    {
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "bak";
      home-manager.extraSpecialArgs = {
        inherit nur vscode-extensions localLib;
      };

      home-manager.users.chetansinghsajwan.imports = [
        {
          dotfiles.features.dev = lib.mkForce true;
          dotfiles.features.gui = lib.mkForce true;
          dotfiles.desktop.gnome.enable = lib.mkForce true;
        }

        ../../home/home.nix
        stylix.homeModules.stylix
        # ../../home/modules/programs/nbfc.nix
      ];
    }
  ];
}
