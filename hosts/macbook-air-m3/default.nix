{
  nur,
  home-manager,
  nix-darwin,
  stylix,
  mkToggleModule,
  ...
}:
nix-darwin.lib.darwinSystem {
  system = "aarch64-darwin";
  modules = [
    ./configuration.nix

    home-manager.darwinModules.home-manager
    {
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "bak";
      home-manager.extraSpecialArgs = {
        inherit nur mkToggleModule;
      };

      home-manager.users.kyutoo.imports = [
        ../../home/home.nix
        ../../config
        stylix.homeModules.stylix

        # host-specific overrides
        {
          dotfiles.user.username = "kyutoo";
        }
      ];
    }
  ];
}
