{ nixpkgs, home-manager, vscode-extensions, ... }: nixpkgs.lib.nixosSystem
{
    system = "x86_64-linux";
    modules = [
        ./configuration.nix

        home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "bakup";
            home-manager.extraSpecialArgs = {
                inherit vscode-extensions;
            };

            home-manager.users.chetan.imports = [ ../../home/home.nix ];
        }
    ];
}
