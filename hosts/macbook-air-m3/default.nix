{
  nur,
  home-manager,
  nix-darwin,
  vscode-extensions,
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
        inherit nur vscode-extensions;
        isLinux = false;
        cfgOverrides = {
          user = {
            username = "kyutoo";
            homeDirectory = "/Users/kyutoo";
            stateVersion = "23.11";
          };
        };
      };

      home-manager.users.kyutoo.imports = [
        ../../home/home.nix
        stylix.homeModules.stylix
      ];
    }
  ];
}
