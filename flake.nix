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
    };

    outputs = { self, nixpkgs, home-manager, vscode-extensions }: {
        nixosConfigurations.nixos = import ./hosts/workstation/host.nix {
            inherit nixpkgs;
            inherit home-manager;
            vscode-extensions = vscode-extensions.extensions."x86_64-linux";
        };
    };
}
