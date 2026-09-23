{
  nixpkgs,
  nur,
  home-manager,
  stylix,
  localLib,
  caelestia-shell,
  silentSDDM,
  helix-wrapped,
  btop-wrapped,
  lazygit-wrapped,
  zellij-wrapped,
  fzf-wrapped,
  yazi-wrapped,
  op-wrapped,
  pv-wrapped,
  eza-wrapped,
  tealdeer-wrapped,
  git-wrapped,
  delta-wrapped,
  docker-wrapped,
  zsh-wrapped,
  ...
}:
let
  inherit (nixpkgs) lib;
in
nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    ../nixos/system.nix
    ./hardware.nix
    { networking.hostName = "honor-m3"; }

    silentSDDM.nixosModules.default

    home-manager.nixosModules.home-manager
    (localLib.mkHomeManagerModule {
      username = "chetansinghsajwan";
      extraSpecialArgs = {
        inherit
          nur
          localLib
          caelestia-shell
          helix-wrapped
          btop-wrapped
          lazygit-wrapped
          zellij-wrapped
          fzf-wrapped
          yazi-wrapped
          op-wrapped
          pv-wrapped
          eza-wrapped
          tealdeer-wrapped
          git-wrapped
          delta-wrapped
          docker-wrapped
          zsh-wrapped
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
        # ../../home/modules/programs/nbfc.nix
        ../../local.nix
      ];
    })
  ];
}
