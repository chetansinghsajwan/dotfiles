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

        # Splits cargo builds into a cached dependency build and our code.
        crane.url = "github:ipetkov/crane";
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
            crane,
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
                    crane
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
        in
        {
            homeConfigurations = llib.forEachSystem (sys: {
                default = mkHome { inherit sys; };
            });

            homeModules.default = { config, lib, ... }: {
                home-manager = {
                    useUserPackages = true;
                    backupFileExtension = "bak";
                    overwriteBackup = true;
                    inherit extraSpecialArgs;
                    users = lib.mapAttrs (_name: u: {
                        imports = homeImports ++ [
                            {
                                dotfiles.currentUser = u;
                            }
                        ];
                    }) config.dotfiles.users;
                };
            };
        };
}
