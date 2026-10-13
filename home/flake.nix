{
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

        llib = {
            url = "path:../lib";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        config = {
            url = "path:../config";
        };

        home-manager = {
            url = "github:nix-community/home-manager/master";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        nur = {
            url = "github:nix-community/nur";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        stylix = {
            url = "github:danth/stylix";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        caelestia-shell = {
            url = "github:caelestia-dots/shell";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        zjstatus = {
            url = "https://github.com/dj95/zjstatus/releases/download/v0.25.0/zjstatus.wasm";
            flake = false;
        };
    };

    outputs =
        {
            nixpkgs,
            llib,
            config,
            home-manager,
            nur,
            stylix,
            caelestia-shell,
            zjstatus,
            ...
        }:
        let
            homeImports = [
                ./home.nix
                config.modules.default
            ];

            extraSpecialArgs = {
                inherit
                    llib
                    nur
                    caelestia-shell
                    zjstatus
                    stylix
                    ;
            };

            mkHome =
                { sys }:
                home-manager.lib.homeManagerConfiguration {
                    pkgs = nixpkgs.legacyPackages.${sys};
                    modules = homeImports;
                    inherit extraSpecialArgs;
                };

            homeModule = {
                home-manager = {
                    useUserPackages = true;
                    backupFileExtension = "bak";
                    overwriteBackup = true;
                    inherit extraSpecialArgs;
                    users.chetansinghsajwan.imports = homeImports;
                };
            };
        in
        {
            homeConfigurations = llib.forEachSystem (sys: {
                default = mkHome { inherit sys; };
            });

            homeModules = {
                nixos.default = homeModule;
                darwin.default = homeModule;
            };
        };
}
