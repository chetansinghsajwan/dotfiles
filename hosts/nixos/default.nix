{
  nixpkgs,
  nur,
  home-manager,
  stylix,
  localLib,
  caelestia-shell,
  silentSDDM,
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
let
  inherit (nixpkgs) lib;
in
nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    ./system.nix
    ./hardware.nix
    { networking.hostName = "nixos"; }

    silentSDDM.nixosModules.default

    home-manager.nixosModules.home-manager
    (localLib.mkHomeManagerModule {
      username = "chetansinghsajwan";
      extraSpecialArgs = {
        inherit
          nur
          localLib
          caelestia-shell
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
        {
          dotfiles.features.dev = lib.mkForce true;
          dotfiles.features.gui = lib.mkForce true;
          dotfiles.desktop.hyprland.enable = lib.mkForce true;
          dotfiles.theme.fonts.rawFontScale = 1.33;
          dotfiles.system.isLinux = lib.mkForce true;
          dotfiles.programs.kanata-layer-indicator.enable = true;
        }

        ../../home/home.nix
        stylix.homeModules.stylix
        ../../local.nix
      ];
    })
  ];
}
