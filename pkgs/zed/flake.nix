{
  description = "zed, wrapped with its settings/keymap/tasks baked in via nix-wrapper-modules";

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

      # The complete zed wrapper (nix-wrapper-modules' generic wrapper
      # mechanism plus this repo's customization, including its own
      # default terminal shell - see modules/module.nix), shared between
      # the home-manager module below and a bare package build.
      wrapperModule = ./modules/module.nix;
    in
    {
      lib = {
        mkZed =
          { pkgs }:
          wrappers.lib.evalPackage [
            { inherit pkgs; }
            wrapperModule
          ];
      };

      # Drop-in home-manager module: `imports = [ zed-wrapped.homeModules.default ];`
      # is the whole integration. Config lands at zed's real
      # ~/.config/zed/{settings,keymap,tasks}.json (via xdg.configFile,
      # sourced from the wrapped package's own generated config) rather
      # than by redirecting XDG_CONFIG_HOME for the wrapped binary - zed
      # also reads fontconfig/GTK config through that same env var, so
      # overriding it wholesale would be a real (and unnecessary) risk.
      homeModules.default =
        { config, lib, ... }:
        let
          wrapper = config.wrappers.zed;
        in
        {
          imports = [
            (wrappers.lib.getInstallModule {
              name = "zed";
              value = wrapperModule;
            })
          ];

          # module.nix's own shellProgram default is read from a
          # standalone, isolated evaluation of config/default.nix alone -
          # it never sees this host's real dotfiles.shell.program
          # override (should any host ever set one in
          # hosts/*/default.nix), so it's explicitly recomputed here from
          # the live value and pushed in.
          config.wrappers.zed.shellProgram = config.dotfiles.shell.program;

          config.xdg.configFile = lib.mkIf wrapper.enable {
            "zed/settings.json".source = wrapper.wrapper.configuration.constructFiles.settings.outPath;
            "zed/keymap.json".source = wrapper.wrapper.configuration.constructFiles.keymap.outPath;
            "zed/tasks.json".source = wrapper.wrapper.configuration.constructFiles.tasks.outPath;
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
