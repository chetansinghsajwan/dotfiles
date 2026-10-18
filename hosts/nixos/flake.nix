{
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

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

        silentSDDM = {
            url = "github:uiriansan/silentsddm";
            inputs.nixpkgs.follows = "nixpkgs";
        };
    };

    outputs =
        {
            nixpkgs,
            home-manager,
            llib,
            home,
            config,
            silentSDDM,
            ...
        }:
        let
            mkNixos =
                { sys }:
                nixpkgs.lib.nixosSystem {
                    system = sys;
                    modules = [
                        # Nixos modules
                        config.modules.default
                        silentSDDM.nixosModules.default
                        ./system.nix
                        ./hardware.nix

                        # Home modules
                        home-manager.nixosModules.home-manager
                        home.homeModules.nixos.default
                    ];
                };
        in
        {
            nixosConfigurations = llib.forEachLinuxSystem (sys: {
                default = mkNixos { inherit sys; };
            });
        };
}
