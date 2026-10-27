{
    description = "Dotfiles";

    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

        home-manager = {
            url = "github:nix-community/home-manager/master";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        treefmt-nix = {
            url = "github:numtide/treefmt-nix";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        nixos = {
            url = "path:./hosts/nixos";
            inputs.nixpkgs.follows = "nixpkgs";
            inputs.home-manager.follows = "home-manager";
            inputs.llib.follows = "llib";
            inputs.config.follows = "config";
            inputs.home.follows = "home";
        };

        nixos-wsl = {
            url = "path:./hosts/nixos-wsl";
            inputs.nixpkgs.follows = "nixpkgs";
            inputs.home-manager.follows = "home-manager";
            inputs.llib.follows = "llib";
            inputs.config.follows = "config";
            inputs.home.follows = "home";
        };

        nixos-honor-m3 = {
            url = "path:./hosts/honor-m3";
            inputs.nixos.follows = "nixos";
        };

        jman-nixos = {
            url = "path:./hosts/jman-nixos";
            inputs.nixos-wsl.follows = "nixos-wsl";
        };

        darwin = {
            url = "path:./hosts/darwin";
            inputs.nixpkgs.follows = "nixpkgs";
            inputs.home-manager.follows = "home-manager";
            inputs.llib.follows = "llib";
            inputs.config.follows = "config";
            inputs.home.follows = "home";
        };

        macbook-air-13 = {
            url = "path:./hosts/macbook-air-13";
            inputs.darwin.follows = "darwin";
        };

        home = {
            url = "path:./home";
            inputs.nixpkgs.follows = "nixpkgs";
            inputs.home-manager.follows = "home-manager";
            inputs.llib.follows = "llib";
            inputs.config.follows = "config";
        };

        llib = {
            url = "path:./lib";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        config = {
            url = "path:./config";
        };
    };

    outputs =
        {
            self,
            nixpkgs,
            treefmt-nix,
            nixos,
            nixos-wsl,
            darwin,
            macbook-air-13,
            nixos-honor-m3,
            home,
            llib,
            jman-nixos,
            ...
        }:
        let
            treefmtEval = llib.forEachSystem (
                sys: treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${sys} ./treefmt.nix
            );

            nixosConfigurations = llib.forEachLinuxSystem (sys: {
                default = nixos.nixosConfigurations.${sys}.default;
                wsl = nixos-wsl.nixosConfigurations.${sys}.default;
            });

            darwinConfigurations = llib.forEachDarwinSystem (sys: {
                default = darwin.darwinConfigurations.${sys}.default;
            });
        in
        {
            nixosConfigurations = nixosConfigurations // {
                honor-m3-nixos = nixos-honor-m3.nixosConfigurations.default;

                # Personal Configurations
                jman-nixos = jman-nixos.nixosConfigurations.default;
            };

            darwinConfigurations = darwinConfigurations // {
                macbook-air13 = macbook-air-13.darwinConfigurations.default;
            };

            homeConfigurations = llib.forEachSystem (sys: {
                default = home.homeConfigurations.${sys}.default;
            });

            # `nix fmt`
            formatter = llib.forEachSystem (sys: treefmtEval.${sys}.config.build.wrapper);

            # `nix flake check` — runs formatter + linters in check mode
            checks = llib.forEachSystem (sys: {
                formatting = treefmtEval.${sys}.config.build.check self;
            });

            # `nix develop` — gives you nixfmt/statix/deadnix/nil on PATH
            devShells = llib.forEachSystem (
                sys:
                let
                    pkgs = nixpkgs.legacyPackages.${sys};
                in
                {
                    default = pkgs.mkShell {
                        packages = with pkgs; [
                            nixfmt
                            statix
                            deadnix
                            nil
                            nixd
                        ];
                    };
                }
            );
        };
}
