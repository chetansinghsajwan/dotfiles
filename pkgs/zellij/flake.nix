{
  description = "zellij, wrapped with its config baked in";

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

      # zellij-forgot shows a floating keybind cheatsheet on demand; the built-in
      # compact-bar tooltip is broken on zellij >=0.44.1 (zellij-org/zellij#5229).
      zellijForgot =
        pkgs:
        pkgs.fetchurl {
          url = "https://github.com/karimould/zellij-forgot/releases/download/0.4.2/zellij_forgot.wasm";
          sha256 = "1ns9wjn1ncjapqpp9nn9kyhqydvl0fbnyiavd0lc3gcxa52l269i";
        };
    in
    {
      lib = {
        mkZellij =
          { pkgs }:
          wrappers.lib.evalPackage [
            { inherit pkgs; }
            baseModule
            wrapperModule
          ];
      };

      # Drop-in home-manager module: `imports = [ zellij-wrapped.homeModules.default ];`
      # is the whole integration.
      homeModules.default =
        { pkgs, ... }:
        {
          imports = [
            (wrappers.lib.getInstallModule {
              name = "zellij";
              value = [
                baseModule
                wrapperModule
              ];
            })
          ];

          config.wrappers.zellij.enable = true;

          # extraConfig's LaunchOrFocusPlugin references this exact path
          # (not zellij's own config dir), so it has to land here verbatim.
          config.home.file."zellij-plugins/zellij_forgot.wasm".source = zellijForgot pkgs;

          config.home.shellAliases.z = "zellij";
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
