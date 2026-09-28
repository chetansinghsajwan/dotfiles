{
  description = "lazygit, wrapped with its config and theme baked in";

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

      # The complete lazygit wrapper (nix-wrapper-modules' generic
      # wrapper mechanism plus this repo's customization, including its
      # own default theme - see modules/module.nix), shared between the
      # home-manager module below and a bare package build. Themed out of
      # the box even with no caller-supplied `colors` at all - see
      # modules/module.nix's default (config.dotfiles.theme.colors).
      wrapperModule = ./modules/module.nix;

      # Builds the same wrapped lazygit both `lib.mkLazygit` (for
      # external callers) and `packages.default` (this flake's own
      # standalone build) use, so there's exactly one module list to keep
      # in sync instead of two.
      mkLazygit =
        {
          pkgs,
          # base16 palette as { base00 = "#hex"; ...; }, e.g.
          # `config.lib.stylix.colors.withHashtag`. Overrides
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
        inherit mkLazygit;
      };

      # Drop-in home-manager module: `imports = [ lazygit-wrapped.homeModules.default ];`
      # is the whole integration - no settings or packages needed at the
      # call site. Themes itself from Stylix when present.
      homeModules.default =
        { config, lib, ... }:
        {
          imports = [
            (wrappers.lib.getInstallModule {
              name = "lazygit";
              value = wrapperModule;
            })
          ];

          # Only overrides module.nix's own default palette when Stylix is
          # actually present - otherwise leaves that default in place
          # rather than forcing colors to null.
          config.wrappers.lazygit.colors = lib.mkIf (lib.hasAttrByPath [
            "lib"
            "stylix"
            "colors"
            "withHashtag"
          ] config) config.lib.stylix.colors.withHashtag;
        };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkLazygit { inherit pkgs; };
        }
      );
    };
}
