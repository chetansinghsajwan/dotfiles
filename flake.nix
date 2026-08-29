{
  description = "system configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nur = {
      url = "github:nix-community/nur";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    stylix = {
      url = "github:danth/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      nur,
      stylix,
      home-manager,
      vscode-extensions,
      nix-darwin,
      treefmt-nix,
      nixos-wsl,
    }:
    let
      linuxSystem = "x86_64-linux";
      darwinSystem = "aarch64-darwin";

      forEachSystem = f: nixpkgs.lib.genAttrs [ linuxSystem darwinSystem ] f;

      treefmtEval = forEachSystem (
        system: treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} ./treefmt.nix
      );
    in
    {
      nixosConfigurations.nixos = import ./hosts/workstation {
        inherit
          nixpkgs
          nur
          home-manager
          stylix
          ;
        vscode-extensions = vscode-extensions.extensions.${linuxSystem};
      };

      darwinConfigurations.macbook-air-m3 = import ./hosts/macbook-air-m3 {
        inherit
          nixpkgs
          nur
          home-manager
          stylix
          nix-darwin
          ;
        vscode-extensions = vscode-extensions.extensions.${darwinSystem};
      };

      nixosConfigurations.wsl = import ./hosts/wsl {
        inherit
          nixpkgs
          nur
          home-manager
          stylix
          nixos-wsl
          ;
        vscode-extensions = vscode-extensions.extensions.${linuxSystem};
      };

      # Standalone Home Manager config (non-NixOS/non-darwin machines,
      # e.g. `home-manager switch --flake .#chetan`)
      homeConfigurations."chetan" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${linuxSystem};

        modules = [
          ./home/home.nix
          stylix.homeModules.stylix
        ];

        extraSpecialArgs = {
          inherit nur;
          vscode-extensions = vscode-extensions.extensions.${linuxSystem};
          isLinux = true;
        };
      };

      # `nix fmt`
      formatter = forEachSystem (system: treefmtEval.${system}.config.build.wrapper);

      # `nix flake check` — runs formatter + linters in check mode
      checks = forEachSystem (system: {
        formatting = treefmtEval.${system}.config.build.check self;
      });

      # `nix develop` — gives you nixfmt/statix/deadnix/nil on PATH
      devShells = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.nixfmt
              pkgs.statix
              pkgs.deadnix
              pkgs.nil
              pkgs.nixd
            ];
          };
        }
      );
    };
}
