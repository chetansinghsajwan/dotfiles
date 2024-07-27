{ nixpkgs, home-manager, vscode-extensions, firefox-extensions, ... }: nixpkgs.lib.nixosSystem
{
  system = "x86_64-linux";
  modules = [
    ./configuration.nix

    home-manager.nixosModules.home-manager
    {
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "bak";
      home-manager.extraSpecialArgs = {
        inherit vscode-extensions;
        inherit firefox-extensions;
      };

      home-manager.users.chetan.imports = [ ../../home/home.nix ];
    }
  ];
}
