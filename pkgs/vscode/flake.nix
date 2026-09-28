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

      # The complete vscode wrapper (nix-wrapper-modules' generic wrapper
      # mechanism plus this repo's customization, including its own
      # default terminal shell - see modules/module.nix), shared between
      # the home-manager module below and a bare package build.
      wrapperModule = ./modules/module.nix;
    in
    {
      lib = {
        mkVscode =
          { pkgs }:
          wrappers.lib.evalPackage [
            { inherit pkgs; }
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
              value = wrapperModule;
            })
          ];

          # module.nix's own shellProgram default is read from a
          # standalone, isolated evaluation of config/default.nix alone -
          # it never sees this host's real dotfiles.shell.program
          # override (should any host ever set one in
          # hosts/*/default.nix), so it's explicitly recomputed here from
          # the live value and pushed in.
          config.wrappers.vscode.shellProgram = config.dotfiles.shell.program;

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
            wrapperModule
          ];
        }
      );
    };
}
