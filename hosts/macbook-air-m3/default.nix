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
    ./system.nix

    home-manager.darwinModules.home-manager
    (localLib.mkHomeManagerModule {
      username = "kyutoo";
      extraSpecialArgs = {
        inherit nur localLib;
      };
      imports = [
        ../../home/home.nix
        stylix.homeModules.stylix

        # host-specific overrides
        {
          dotfiles.user.username = "kyutoo";
          dotfiles.theme.fonts.rawFontScale = 1.0;
          dotfiles.system.isDarwin = true;
        }
      ];
    })
  ];
}
