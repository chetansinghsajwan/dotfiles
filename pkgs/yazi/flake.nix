{
  description = "yazi, wrapped with its plugins, keymap, and theme baked in";

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

      # The complete yazi wrapper (nix-wrapper-modules' own native yazi
      # module plus this repo's customization, including its own default
      # theme - see modules/module.nix), shared between the home-manager
      # module below and a bare package build. Themed out of the box even
      # with no caller-supplied `colors` at all - see
      # modules/module.nix's default (config.dotfiles.theme.colors).
      wrapperModule = ./modules/module.nix;

      # Builds the same wrapped yazi both `lib.mkYazi` (for external callers)
      # and `packages.default` (this flake's own standalone build) use, so
      # there's exactly one module list to keep in sync instead of two.
      mkYazi =
        {
          pkgs,
          # base16 palette as { base00 = "#hex"; ...; cyan = "#hex"; ... },
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
        inherit mkYazi;
      };

      # Drop-in home-manager module: `imports = [ yazi-wrapped.homeModules.default ];`
      # is the whole integration - no settings, packages, or shell wiring
      # needed at the call site. Themes itself from Stylix when present,
      # and wires the `y` (cd-on-quit) shell function into whichever of
      # zsh/fish/nushell is enabled.
      homeModules.default =
        {
          config,
          lib,
          ...
        }:
        let
          wrapper = config.wrappers.yazi;
          files = wrapper.wrapper.configuration.constructFiles;
        in
        {
          imports = [
            (wrappers.lib.getInstallModule {
              name = "yazi";
              value = wrapperModule;
            })
          ];

          # Only overrides module.nix's own default palette when Stylix is
          # actually present - otherwise leaves that default in place
          # rather than forcing colors to null.
          config.wrappers.yazi.colors = lib.mkIf (lib.hasAttrByPath [
            "lib"
            "stylix"
            "colors"
            "withHashtag"
          ] config) config.lib.stylix.colors.withHashtag;

          config.home.file = {
            ".config/yazi/y.sh" = lib.mkIf config.programs.zsh.enable { source = files.ySh.outPath; };
            ".config/yazi/y.fish" = lib.mkIf config.programs.fish.enable {
              source = files.yFish.outPath;
            };
            ".config/yazi/y.nu" = lib.mkIf config.programs.nushell.enable { source = files.yNu.outPath; };
          };

          config.wrappers.zsh.extraInitContent = lib.mkIf config.programs.zsh.enable ''
            source ~/.config/yazi/y.sh
          '';

          config.programs.fish.interactiveShellInit = lib.mkIf config.programs.fish.enable ''
            source ~/.config/yazi/y.fish
          '';

          config.programs.nushell.extraConfig = lib.mkIf config.programs.nushell.enable (
            builtins.readFile ./resources/y.nu
          );
        };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkYazi { inherit pkgs; };
        }
      );
    };
}
