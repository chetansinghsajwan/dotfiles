{
  description = "system configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nur.url = "github:nix-community/nur";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nur, home-manager, vscode-extensions }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.nixos = import ./hosts/workstation/host.nix {
        inherit nixpkgs;
        inherit nur;
        inherit home-manager;
        vscode-extensions = vscode-extensions.extensions.${system};
      };
    };
}
