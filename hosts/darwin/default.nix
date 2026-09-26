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
          dotfiles.user.username = "chetansinghsajwan";
          dotfiles.theme.fonts.rawFontScale = 1.0;
          dotfiles.system.isDarwin = true;
        }

        ../../local.nix
      ];
    })
  ];
}
