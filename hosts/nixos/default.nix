{
  nixpkgs,
  nur,
  home-manager,
  stylix,
  localLib,
  caelestia-shell,
  ...
}:
let
  inherit (nixpkgs) lib;
in
nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    ./system.nix

    home-manager.nixosModules.home-manager
    (localLib.mkHomeManagerModule {
      username = "chetansinghsajwan";
      extraSpecialArgs = {
        inherit nur localLib caelestia-shell;
      };
      imports = [
        {
          dotfiles.features.dev = lib.mkForce true;
          dotfiles.features.gui = lib.mkForce true;
          dotfiles.desktop.hyprland.enable = lib.mkForce true;
          dotfiles.theme.fonts.rawFontScale = 1.33;
          dotfiles.system.isLinux = lib.mkForce true;
        }

        ../../home/home.nix
        stylix.homeModules.stylix
        # ../../home/modules/programs/nbfc.nix
        ../../local.nix
      ];
    })
  ];
}
