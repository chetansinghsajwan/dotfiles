{
  description = "system configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nur.url = "github:nix-community/nur";
    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-26.05";
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
  };

  outputs = { self, nixpkgs, nur, home-manager, vscode-extensions, nix-darwin }:
    let
      linuxSystem = "x86_64-linux";
      darwinSystem = "aarch64-darwin";
    in
    {
      nixosConfigurations.nixos = import ./hosts/workstation/host.nix {
        inherit nixpkgs;
        inherit nur;
        inherit home-manager;
        vscode-extensions = vscode-extensions.extensions.${linuxSystem};
      };

      darwinConfigurations.macbook-air-m3 = import ./hosts/macbook-air-m3/host.nix {
        inherit nixpkgs;
        inherit nur;
        inherit home-manager;
        inherit nix-darwin;
        vscode-extensions = vscode-extensions.extensions.${darwinSystem};
      };
    };
}
