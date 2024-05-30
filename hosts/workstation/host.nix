{ nixpkgs, home-manager, ... }: nixpkgs.lib.nixosSystem
{
    system = "x86_64-linux";
    modules = [
        ./configuration.nix

        home-manager.nixosModules.home-manager {
            # home-manager.useGlobalPackages = true;
            home-manager.useUserPackages = true;
            home-manager.users.chetan = import ../../home/home.nix;
        }
    ];
}
