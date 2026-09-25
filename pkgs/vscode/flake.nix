{
  description = "vscode, wrapped with its settings/keybindings/tasks/extensions baked in via nix-wrapper-modules";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    wrappers = {
      url = "github:nix-community/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, wrappers, ... }:
    let
      inherit (nixpkgs) lib;

      forEachSystem =
        f:
        lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ] f;

      wrapperModule = ./module.nix;
      baseModule = ./wrapper-module.nix;
    in
    {
      lib = {
        mkVscode =
          { pkgs }:
          wrappers.lib.evalPackage [
            { inherit pkgs; }
            baseModule
            wrapperModule
          ];
      };

      # Drop-in home-manager module: `imports = [ vscode-wrapped.homeModules.default ];`
      # is the whole integration. Config and extensions land at VS Code's
      # real paths (via home.file, sourced from the wrapped package's own
      # generated config/extensionsDrv) rather than by redirecting
      # XDG_CONFIG_HOME for the wrapped binary - same reasoning as zed.
      homeModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          wrapper = config.wrappers.vscode;

          # Same platform split home-manager's own programs.vscode uses:
          # macOS keeps its settings under Application Support, everywhere
          # else follows XDG. Extensions always live at ~/.vscode/extensions
          # regardless of platform. Relative to $HOME (not absolute), since
          # that's what home.file's keys expect.
          userDirRel =
            if pkgs.stdenv.hostPlatform.isDarwin then
              "Library/Application Support/Code/User"
            else
              ".config/Code/User";
        in
        {
          imports = [
            (wrappers.lib.getInstallModule {
              name = "vscode";
              value = [
                baseModule
                wrapperModule
              ];
            })
          ];

          config.wrappers.vscode.userSettings."terminal.integrated.defaultProfile" = {
            windows = config.dotfiles.shell.program;
            linux = config.dotfiles.shell.program;
            osx = config.dotfiles.shell.program;
          };

          config.home.file = lib.mkIf wrapper.enable {
            "${userDirRel}/settings.json".source =
              wrapper.wrapper.configuration.constructFiles.settings.outPath;
            "${userDirRel}/keybindings.json".source =
              wrapper.wrapper.configuration.constructFiles.keybindings.outPath;
            "${userDirRel}/tasks.json".source = wrapper.wrapper.configuration.constructFiles.tasks.outPath;
            ".vscode/extensions".source =
              "${wrapper.wrapper.configuration.extensionsDrv}/share/vscode/extensions";
          };
        };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = wrappers.lib.evalPackage [
            { inherit pkgs; }
            baseModule
            wrapperModule
          ];
        }
      );
    };
}
