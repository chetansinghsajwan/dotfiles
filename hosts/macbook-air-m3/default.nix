{
  nur,
  home-manager,
  nix-darwin,
  vscode-extensions,
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
        inherit nur vscode-extensions mkToggleModule;
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
