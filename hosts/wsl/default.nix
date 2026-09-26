{
  nixpkgs,
  nur,
  home-manager,
  stylix,
  nixos-wsl,
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
let
  inherit (nixpkgs) lib;
in
nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    nixos-wsl.nixosModules.default
    ./system.nix

    home-manager.nixosModules.home-manager
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

        {
          dotfiles.features.gui = lib.mkForce false;
          dotfiles.desktop.gnome.enable = lib.mkForce false;
          dotfiles.desktop.hyprland.enable = lib.mkForce false;
          dotfiles.system.isWsl = lib.mkForce true;
          dotfiles.system.isLinux = lib.mkForce true;
        }

        ../../local.nix
      ];
    })
  ];
}
