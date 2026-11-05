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

        term-toolkit = {
            url = "path:../pkgs/term-toolkit";
            inputs.nixpkgs.follows = "nixpkgs";
            inputs.llib.follows = "llib";
            inputs.crane.follows = "crane";
        };

        pick = {
            url = "path:../pkgs/pick";
            inputs.nixpkgs.follows = "nixpkgs";
            inputs.term-toolkit.follows = "term-toolkit";
        };

        pv = {
            url = "path:../pkgs/pv";
            inputs.nixpkgs.follows = "nixpkgs";
            inputs.term-toolkit.follows = "term-toolkit";
        };

        files = {
            url = "path:../pkgs/files";
            inputs.nixpkgs.follows = "nixpkgs";
            inputs.term-toolkit.follows = "term-toolkit";
        };

        gu = {
            url = "path:../pkgs/gu";
            inputs.nixpkgs.follows = "nixpkgs";
            inputs.term-toolkit.follows = "term-toolkit";
        };

        tb = {
            url = "path:../pkgs/tb";
            inputs.nixpkgs.follows = "nixpkgs";
            inputs.term-toolkit.follows = "term-toolkit";
        };

        nu = {
            url = "path:../pkgs/nu";
            inputs.nixpkgs.follows = "nixpkgs";
            inputs.term-toolkit.follows = "term-toolkit";
        };

        mdexport = {
            url = "path:../pkgs/mdexport";
            inputs.nixpkgs.follows = "nixpkgs";
            inputs.term-toolkit.follows = "term-toolkit";
        };

        helix-fork = {
            url = "path:../pkgs/helix";
            inputs.nixpkgs.follows = "nixpkgs";
            inputs.term-toolkit.follows = "term-toolkit";
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
            pick,
            pv,
            files,
            gu,
            tb,
            nu,
            mdexport,
            helix-fork,
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
                    stylix
                    ;

                # Flakes of our Rust tools (pkgs/); each has `packages.<system>.default`.
                tools = {
                    inherit
                        pick
                        pv
                        files
                        gu
                        tb
                        nu
                        mdexport
                        helix-fork
                        ;
                };
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
