{ nixpkgs, home-manager, ... }: nixpkgs.lib.nixosSystem
{
    system = "x86_64-linux";
    modules = [
        ./configuration.nix

        home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "bak";
            home-manager.users.chetan = import ../../home/home.nix;
        }
    ];
}
