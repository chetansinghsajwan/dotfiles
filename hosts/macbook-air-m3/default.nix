{
  nur,
  home-manager,
  nix-darwin,
  stylix,
  localLib,
  yazi-wrapped,
  lazygit-wrapped,
  btop-wrapped,
  helix-wrapped,
  tealdeer-wrapped,
  eza-wrapped,
  fzf-wrapped,
  git-wrapped,
  zellij-wrapped,
  zsh-wrapped,
  op-wrapped,
  pv-wrapped,
  docker-wrapped,
  nixpkgs-wrapped,
  starship-wrapped,
  direnv-wrapped,
  batman-wrapped,
  zed-wrapped,
  vscode-wrapped,
  vlc-wrapped,
  ghostty-wrapped,
  firefox-wrapped,
  dconf-editor-wrapped,
  epiphany-wrapped,
  gnome-terminal-wrapped,
  gnome-text-editor-wrapped,
  kanata-layer-indicator-wrapped,
  libreoffice-wrapped,
  nbfc-linux-wrapped,
  clipboard-wrapped,
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
          yazi-wrapped
          lazygit-wrapped
          btop-wrapped
          helix-wrapped
          tealdeer-wrapped
          eza-wrapped
          fzf-wrapped
          git-wrapped
          zellij-wrapped
          zsh-wrapped
          op-wrapped
          pv-wrapped
          docker-wrapped
          nixpkgs-wrapped
          starship-wrapped
          direnv-wrapped
          batman-wrapped
          zed-wrapped
          vscode-wrapped
          vlc-wrapped
          ghostty-wrapped
          firefox-wrapped
          dconf-editor-wrapped
          epiphany-wrapped
          gnome-terminal-wrapped
          gnome-text-editor-wrapped
          kanata-layer-indicator-wrapped
          libreoffice-wrapped
          nbfc-linux-wrapped
          clipboard-wrapped
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
