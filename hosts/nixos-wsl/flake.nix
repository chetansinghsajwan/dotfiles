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
                        home.homeModules.default
                    ];
                };
        in
        {
            nixosConfigurations = llib.forEachLinuxSystem (sys: {
                default = mkNixos { inherit sys; };
            });
        };
}
