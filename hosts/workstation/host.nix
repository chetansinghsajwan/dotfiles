inputs: inputs.nixpkgs.lib.nixosSystem
{
    system = "x86_64-linux";
    modules = [
        ./configuration.nix

        inputs.home-manager.nixosModules.home-manager {
            home-manager.useUserPackages = true;
            home-manager.users.chetan = import ../../home/home.nix;
        }
    ];

    specialArgs = { inherit inputs; };
}
