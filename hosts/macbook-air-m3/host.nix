{ nixpkgs, nur, home-manager, nix-darwin, vscode-extensions, ... }:
nix-darwin.lib.darwinSystem
{
  system = "aarch64-darwin";
  modules = [
    ./configuration.nix
    home-manager.darwinModules.home-manager
    {
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "bak";
      home-manager.extraSpecialArgs = {
        inherit nur;
        inherit vscode-extensions;
        isLinux = false;
        userConfig = {
          username = "kyutoo";
          name = "kyutoo";
          email = "76040441+chetansinghsajwan@users.noreply.github.com";
          homeDirectory = "/Users/kyutoo";
          stateVersion = "23.11";
        };
      };

      home-manager.users.kyutoo.imports = [ ../../home/home.nix ];
    }
  ];
}
