{
  nixpkgs,
  nur,
  home-manager,
  stylix,
  vscode-extensions,
  ...
}:
nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    ./configuration.nix

    home-manager.nixosModules.home-manager
    {
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "bak";
      home-manager.extraSpecialArgs = {
        inherit nur;
        inherit vscode-extensions;
        isLinux = true;
      };

      home-manager.users.chetansinghsajwan.imports = [
        ../../home/home.nix
        stylix.homeModules.stylix
        # ../../home/modules/programs/nbfc.nix
      ];
    }
  ];
}
