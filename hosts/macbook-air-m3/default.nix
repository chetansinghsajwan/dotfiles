{
  wrappedPkgs,
  nur,
  home-manager,
  nix-darwin,
  stylix,
  llib,
  ...
}:
nix-darwin.lib.darwinSystem {
  system = "aarch64-darwin";
  modules = [
    ./system.nix
    {
      system.primaryUser = "kyutoo";
      dotfiles.user.username = "kyutoo";
    }

    home-manager.darwinModules.home-manager
    (llib.mkHomeManagerModule {
      username = "kyutoo";
      extraSpecialArgs = {
        inherit wrappedPkgs nur llib;
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

        ../../local.nix
      ];
    })
  ];
}
