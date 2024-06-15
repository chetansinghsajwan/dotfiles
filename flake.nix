{
  description = "system configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    firefox-extensions = {
      url = "gitlab:rycee/nur-expressions?dir=pkgs/firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, vscode-extensions, firefox-extensions }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.nixos = import ./hosts/workstation/host.nix {
        inherit nixpkgs;
        inherit home-manager;
        vscode-extensions = vscode-extensions.extensions.${system};
        firefox-extensions = firefox-extensions.packages.${system};
      };
    };
}
