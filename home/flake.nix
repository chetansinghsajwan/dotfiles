{
    description = "home-manager configuration";

    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

        home-manager = {
            url = "github:nix-community/home-manager";
            inputs.nixpkgs.follows = "nixpkgs";
        };

        nbfc-linux = {
            url = "github:nbfc-linux/nbfc-linux";
            inputs.nixpkgs.follows = "nixpkgs";
        };
    };

    outputs = inputs:
    let
        system = "x86_64-linux";
        pkgs = inputs.nixpkgs.legacyPackages.${system};
    in
    {
        homeConfigurations."chetan" = inputs.home-manager.lib.homeManagerConfiguration {
            inherit pkgs;

            modules = [ ./home.nix ];

            extraSpecialArgs = {
                inherit inputs;
            };
        };
    };
}
