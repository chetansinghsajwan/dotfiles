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
      url = "github:LnL7/nix-darwin";
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

    treefmt-nix.url = "github:numtide/treefmt-nix";

    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    silentSDDM = {
      url = "github:uiriansan/SilentSDDM";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    helix-wrapped = {
      url = "path:./pkgs/helix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    btop-wrapped = {
      url = "path:./pkgs/btop";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    lazygit-wrapped = {
      url = "path:./pkgs/lazygit";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zellij-wrapped = {
      url = "path:./pkgs/zellij";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    fzf-wrapped = {
      url = "path:./pkgs/fzf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nur,
      stylix,
      home-manager,
      nix-darwin,
      treefmt-nix,
      nixos-wsl,
      caelestia-shell,
      silentSDDM,
      helix-wrapped,
      btop-wrapped,
      lazygit-wrapped,
      zellij-wrapped,
      fzf-wrapped,
    }:
    let
      linuxSystem = "x86_64-linux";
      darwinSystem = "aarch64-darwin";

      forEachSystem = f: nixpkgs.lib.genAttrs [ linuxSystem darwinSystem ] f;

      treefmtEval = forEachSystem (
        system: treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} ./treefmt.nix
      );

      localLib = import ./lib { inherit (nixpkgs) lib; };
    in
    {
      nixosConfigurations.nixos = import ./hosts/nixos {
        inherit
          nixpkgs
          nur
          home-manager
          stylix
          localLib
          caelestia-shell
          silentSDDM
          helix-wrapped
          btop-wrapped
          lazygit-wrapped
          zellij-wrapped
          fzf-wrapped
          ;
      };

      nixosConfigurations.honor-m3 = import ./hosts/honor-m3 {
        inherit
          nixpkgs
          nur
          home-manager
          stylix
          localLib
          caelestia-shell
          silentSDDM
          helix-wrapped
          btop-wrapped
          lazygit-wrapped
          zellij-wrapped
          fzf-wrapped
          ;
      };

      darwinConfigurations.macbook-air-m3 = import ./hosts/macbook-air-m3 {
        inherit
          nixpkgs
          nur
          home-manager
          stylix
          nix-darwin
          localLib
          helix-wrapped
          btop-wrapped
          lazygit-wrapped
          zellij-wrapped
          fzf-wrapped
          ;
      };

      darwinConfigurations.darwin = import ./hosts/darwin {
        inherit
          nixpkgs
          nur
          home-manager
          stylix
          nix-darwin
          localLib
          helix-wrapped
          btop-wrapped
          lazygit-wrapped
          zellij-wrapped
          fzf-wrapped
          ;
      };

      nixosConfigurations.wsl = import ./hosts/wsl {
        inherit
          nixpkgs
          nur
          home-manager
          stylix
          nixos-wsl
          localLib
          helix-wrapped
          btop-wrapped
          lazygit-wrapped
          zellij-wrapped
          fzf-wrapped
          ;
      };

      # Standalone Home Manager config (non-NixOS/non-darwin machines,
      # e.g. `home-manager switch --flake .#chetan`)
      homeConfigurations."chetan" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.${linuxSystem};

        modules = [
          ./home/home.nix
          stylix.homeModules.stylix
          { dotfiles.system.isLinux = true; }
          ./local.nix
        ];

        extraSpecialArgs = {
          inherit
            nur
            localLib
            caelestia-shell
            helix-wrapped
            btop-wrapped
            lazygit-wrapped
            zellij-wrapped
            fzf-wrapped
            ;
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
