{
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

        nixos-wsl = {
            url = "github:nix-community/NixOS-WSL";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        home-manager = {
            url = "github:nix-community/home-manager/master";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        home = {
            url = "path:../../home";
            inputs.nixpkgs.follows = "nixpkgs";
            inputs.home-manager.follows = "home-manager";
            inputs.llib.follows = "llib";
            inputs.config.follows = "config";
        };

        llib = {
            url = "path:../../lib";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        config = {
            url = "path:../../config";
        };
    };

    outputs =
        {
            nixpkgs,
            nixos-wsl,
            home-manager,
            llib,
            home,
            config,
            ...
        }:
        let
            mkNixos =
                { sys }:
                nixpkgs.lib.nixosSystem {
                    system = sys;
                    modules = [
                        config.modules.default
                        nixos-wsl.nixosModules.default
                        ./system.nix

                        home-manager.nixosModules.home-manager
                        home.homeModules.nixos.default

                        # The home-manager module tree has its own, separate
                        # `dotfiles` instance — the overrides in ./system.nix
                        # only apply to the NixOS one. Without this, stylix's
                        # gtk/gnome dconf targets stay enabled by default and
                        # activation fails on WSL (no session D-Bus/dconf).
                        {
                            home-manager.users.chetansinghsajwan.imports = [
                                {
                                    dotfiles.system.isWsl = nixpkgs.lib.mkForce true;
                                    dotfiles.system.isLinux = nixpkgs.lib.mkForce true;
                                    dotfiles.features.gui = nixpkgs.lib.mkForce false;
                                    dotfiles.desktop.gnome.enable = nixpkgs.lib.mkForce false;
                                    dotfiles.desktop.hyprland.enable = nixpkgs.lib.mkForce false;
                                }
                            ];
                        }
                    ];
                };
        in
        {
            nixosConfigurations = llib.forEachLinuxSystem (sys: {
                default = mkNixos { inherit sys; };
            });
        };
}
