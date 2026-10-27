{
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

        llib = {
            url = "path:../../lib";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        config = {
            url = "path:../../config";
        };

        nix-darwin = {
            url = "github:LnL7/nix-darwin";
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
    };

    outputs =
        {
            llib,
            nix-darwin,
            home-manager,
            home,
            config,
            ...
        }:
        let
            mkDarwinCfg =
                sys:
                nix-darwin.lib.darwinSystem {
                    system = sys;
                    modules = [
                        # Darwin modules
                        config.modules.default
                        ./system.nix

                        # Home modules
                        home-manager.darwinModules.home-manager
                        home.homeModules.default
                    ];
                };
        in
        {
            darwinConfigurations = llib.forEachDarwinSystem (sys: {
                default = mkDarwinCfg sys;
            });
        };
}
