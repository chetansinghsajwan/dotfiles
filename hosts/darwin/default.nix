{
  nur,
  home-manager,
  nix-darwin,
  stylix,
  localLib,
  ...
}:
nix-darwin.lib.darwinSystem {
  system = "aarch64-darwin";
  modules = [
    ../macbook-air-m3/system.nix
    {
      networking.hostName = "darwin";
      system.primaryUser = "chetansinghsajwan";
      dotfiles.user.username = "chetansinghsajwan";
    }

    home-manager.darwinModules.home-manager
    (localLib.mkHomeManagerModule {
      username = "chetansinghsajwan";
      extraSpecialArgs = {
        inherit nur localLib;
      };
      imports = [
        ../../home/home.nix
        stylix.homeModules.stylix

        # host-specific overrides
        {
          dotfiles.user.username = "chetansinghsajwan";
          dotfiles.theme.fonts.rawFontScale = 1.0;
          dotfiles.system.isDarwin = true;
        }

        ../../local.nix
      ];
    })
  ];
}
