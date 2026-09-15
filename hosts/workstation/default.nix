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
    {
      dotfiles.desktop.hyprland.enable = true;
      dotfiles.system.displayManager = "gdm";
      dotfiles.system.extraGroups = [
        "wheel"
      ];
      dotfiles.system.isLinux = true;
    }

    {
      imports = [
        ../../config
        ../shared.nix
        ./system.nix
        ./hardware.nix
        ../kanata
      ];
    }

    home-manager.nixosModules.home-manager
    {
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "bak";
      home-manager.overwriteBackup = true;
      home-manager.extraSpecialArgs = {
        inherit nur localLib caelestia-shell;
      };

      home-manager.users.chetansinghsajwan.imports = [
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
      ];
    }
  ];
}
