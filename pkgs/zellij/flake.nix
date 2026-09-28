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

      # The complete zellij wrapper (nix-wrapper-modules' generic wrapper
      # mechanism plus this repo's customization, including its own
      # default theme - see modules/module.nix), shared between the
      # home-manager module below and a bare package build. Themed out
      # of the box even with no caller-supplied `colors` at all - see
      # modules/module.nix's default (config.dotfiles.theme.colors).
      wrapperModule = ./modules/module.nix;

      # zellij-forgot shows a floating keybind cheatsheet on demand; the built-in
      # compact-bar tooltip is broken on zellij >=0.44.1 (zellij-org/zellij#5229).
      zellijForgot =
        pkgs:
        pkgs.fetchurl {
          url = "https://github.com/karimould/zellij-forgot/releases/download/0.4.2/zellij_forgot.wasm";
          sha256 = "1ns9wjn1ncjapqpp9nn9kyhqydvl0fbnyiavd0lc3gcxa52l269i";
        };

      # Builds the same wrapped zellij both `lib.mkZellij` (for external
      # callers) and `packages.default` (this flake's own standalone
      # build) use, so there's exactly one module list to keep in sync
      # instead of two.
      mkZellij =
        {
          pkgs,
          # base16 palette as { base00 = "#hex"; ...; base0F = "#hex"; },
          # e.g. `config.lib.stylix.colors.withHashtag`. Overrides
          # module.nix's own default palette when given; left alone
          # (module.nix's default applies) when null.
          colors ? null,
        }:
        wrappers.lib.evalPackage (
          [
            { inherit pkgs; }
            wrapperModule
          ]
          ++ lib.optional (colors != null) { config.colors = colors; }
        );
    in
    {
      lib = {
        inherit mkZellij;
      };

      # Drop-in home-manager module: `imports = [ zellij-wrapped.homeModules.default ];`
      # is the whole integration. Themes itself from Stylix when present.
      homeModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        {
          imports = [
            (wrappers.lib.getInstallModule {
              name = "zellij";
              value = wrapperModule;
            })
          ];

          # Only overrides module.nix's own default palette when Stylix is
          # actually present - otherwise leaves that default in place
          # rather than forcing colors to null.
          config.wrappers.zellij.colors = lib.mkIf (lib.hasAttrByPath [
            "lib"
            "stylix"
            "colors"
            "withHashtag"
          ] config) config.lib.stylix.colors.withHashtag;

          # extraConfig's LaunchOrFocusPlugin references this exact path
          # (not zellij's own config dir), so it has to land here verbatim.
          # This can't move into module.nix's own constructFiles the way
          # other packages' resource files did: LaunchOrFocusPlugin needs
          # a stable $HOME-relative path, not a store path that changes
          # every rebuild, so it's inherently home-manager's job (home.file
          # places things in $HOME; module.nix's own build output can't).
          config.home.file."zellij-plugins/zellij_forgot.wasm".source = zellijForgot pkgs;

          config.home.shellAliases.z = "zellij";
        };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkZellij { inherit pkgs; };
        }
      );
    };
}
