{
    description = "Dotfiles";

    inputs = {
        # Include git submodules (pkgs/tuikit, pkgs/helix-improved) in this flake's source.
        self.submodules = true;

        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

        # semgrep-core fails to build on the current unstable (a patchelf assertion), so semgrep comes
        # from this older revision. Drop it when unstable builds semgrep again.
        nixpkgs-semgrep.url = "github:nixos/nixpkgs/d5cc6833999746cffdfe0598f7bc801a57b887a9";

        home-manager = {
            url = "github:nix-community/home-manager/master";
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

    outputs = {
        nixpkgs,
        nixpkgs-semgrep,
        nixos,
        nixos-wsl,
        darwin,
        macbook-air-13,
        nixos-honor-m3,
        home,
        llib,
        jman-nixos,
        ...
    }: let
        nixosConfigurations = llib.forEachLinuxSystem (sys: {
            default = nixos.nixosConfigurations.${sys}.default;
            wsl = nixos-wsl.nixosConfigurations.${sys}.default;
        });

        darwinConfigurations = llib.forEachDarwinSystem (sys: {
            default = darwin.darwinConfigurations.${sys}.default;
        });
    in {
        nixosConfigurations =
            nixosConfigurations
            // {
                honor-m3-nixos = nixos-honor-m3.nixosConfigurations.default;

                # Personal Configurations
                jman-nixos = jman-nixos.nixosConfigurations.default;
            };

        darwinConfigurations =
            darwinConfigurations
            // {
                macbook-air13 = macbook-air-13.darwinConfigurations.default;
            };

        homeConfigurations = llib.forEachSystem (sys: {
            default = home.homeConfigurations.${sys}.default;
        });

        # `nix develop` gives every tool that `task` and the git hooks call.
        devShells = llib.forEachSystem (
            sys: let
                pkgs = nixpkgs.legacyPackages.${sys};
            in {
                default = pkgs.mkShell {
                    packages = with pkgs; [
                        # Task runner and git hooks.
                        go-task
                        lefthook
                        cocogitto

                        # Formatters and linters.
                        treefmt
                        alejandra
                        statix
                        deadnix
                        shfmt
                        shellcheck
                        stylua
                        ruff
                        taplo
                        dprint
                        rumdl
                        yamlfmt
                        actionlint
                        zizmor
                        typos
                        rustfmt
                        clippy

                        # Rust (pkgs/kb), tests and vulnerability scanners.
                        cargo
                        rustc
                        cargo-nextest
                        cargo-deny
                        osv-scanner
                        gitleaks
                        nixpkgs-semgrep.legacyPackages.${sys}.semgrep

                        # Nix language servers.
                        nil
                        nixd
                    ];
                };
            }
        );
    };
}
