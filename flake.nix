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

                # hk reads its config (hk.pkl) with pkl. nixpkgs builds pkl from source with Gradle (about
                # 1.4 GiB of downloads, not in the binary cache), so the upstream release binary is used.
                pkl = let
                    release = "0.33.0";
                    asset =
                        {
                            x86_64-linux = {
                                name = "linux-amd64";
                                hash = "sha256-uabd6ms4K31NtM9453qjhY4Min4Ck50rophXS10fzGk=";
                            };
                            aarch64-darwin = {
                                name = "macos-aarch64";
                                hash = "sha256-45wVffDwCjXTS0YnCnaHhO3K9Qmq+/dDhJsntMg++Ds=";
                            };
                        }.${
                            sys
                        };
                in
                    pkgs.stdenv.mkDerivation {
                        pname = "pkl";
                        version = release;
                        src = pkgs.fetchurl {
                            url = "https://github.com/apple/pkl/releases/download/${release}/pkl-${asset.name}";
                            inherit (asset) hash;
                        };
                        dontUnpack = true;
                        nativeBuildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [pkgs.autoPatchelfHook];
                        buildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [pkgs.zlib pkgs.stdenv.cc.cc.lib];
                        installPhase = "install -Dm755 $src $out/bin/pkl";
                    };
            in {
                default = pkgs.mkShell {
                    packages = with pkgs; [
                        # Task runner, git hooks (hk with its pkl config reader) and commit linting.
                        go-task
                        hk
                        pkl
                        cocogitto

                        # Formatters and linters.
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
