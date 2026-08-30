{
  nixpkgs,
  nur,
  home-manager,
  stylix,
  nixos-wsl,
  vscode-extensions,
  ...
}:
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
        inherit nur vscode-extensions;
        isLinux = true;
      };

      home-manager.users.chetansinghsajwan.imports = [
        ../../home/home.nix
        ../../config
        stylix.homeModules.stylix

        {
          dotfiles.user.username = "chetansinghsajwan";
          dotfiles.user.homeDirectory = "/home/chetansinghsajwan";
          dotfiles.user.stateVersion = "23.11";
          dotfiles.features.gui = false;
        }
      ];
    }
  ];
}
