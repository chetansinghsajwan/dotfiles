{
    description = "system configuration";

    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
        home-manager = {
            url = "github:nix-community/home-manager/master";
            inputs.nixpkgs.follows = "nixpkgs";
        };
    };

    outputs = { self, nixpkgs, home-manager }: {
        nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
                ./configuration.nix
        
                home-manager.nixosModules.home-manager {
                    # home-manager.useGlobalPackages = true;
                    home-manager.useUserPackages = true;
                    home-manager.users.chetan = import ../nix/home-manager/home.nix;
                }
            ];
        };
    };
}
