{
  nur,
  home-manager,
  nix-darwin,
  stylix,
  localLib,
  helix-wrapped,
  btop-wrapped,
  lazygit-wrapped,
  zellij-wrapped,
  fzf-wrapped,
  yazi-wrapped,
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
    (localLib.mkHomeManagerModule {
      username = "kyutoo";
      extraSpecialArgs = {
        inherit
          nur
          localLib
          helix-wrapped
          btop-wrapped
          lazygit-wrapped
          zellij-wrapped
          fzf-wrapped
          yazi-wrapped
          ;
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
