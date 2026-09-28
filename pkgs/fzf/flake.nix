{
  description = "fzf, wrapped with its options and theme baked in";

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

      # The complete fzf wrapper (popup layout, binds, theme, picker
      # functions - see modules/module.nix), shared between the
      # home-manager module below and a bare package build. Themed out
      # of the box even with no caller-supplied `colors` at all - see
      # modules/module.nix's default (config.dotfiles.theme.colors).
      wrapperModule = ./modules/module.nix;

      # Builds the same wrapped fzf both `lib.mkFzf` (for external
      # callers) and `packages.default` (this flake's own standalone
      # build) use, so there's exactly one module list to keep in sync
      # instead of two.
      mkFzf =
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
        inherit mkFzf;
      };

      # Drop-in home-manager module: `imports = [ fzf-wrapped.homeModules.default ];`
      # is the whole integration - installs itself, the picker functions
      # (ff/fs/fp/fe/fcmd/fssh/fh + the git.sh pickers' shared __fzf helper),
      # and the alt-t/ctrl-r/alt-c/alt-g ZLE widgets, themed from Stylix
      # when present.
      homeModules.default =
        {
          config,
          lib,
          ...
        }:
        let
          wrapper = config.wrappers.fzf;
          files = wrapper.wrapper.configuration.constructFiles;
        in
        {
          imports = [
            (wrappers.lib.getInstallModule {
              name = "fzf";
              value = wrapperModule;
            })
          ];

          # Only overrides module.nix's own default palette when Stylix is
          # actually present - otherwise leaves that default in place
          # rather than forcing colors to null.
          config.wrappers.fzf.colors = lib.mkIf (lib.hasAttrByPath [
            "lib"
            "stylix"
            "colors"
            "withHashtag"
          ] config) config.lib.stylix.colors.withHashtag;

          config.wrappers.fzf.histfile = config.programs.zsh.history.path;

          # bat stays on home-manager's own `programs.bat` (not plain
          # home.packages) so stylix's bat target still fires - it
          # generates the "base16-stylix" bat theme that both delta's
          # syntax-theme and pv's bat-based previews depend on.
          config.programs.bat.enable = true;

          config.home.file = {
            ".config/fzf/fzf.sh".source = files.fzfSh.outPath;
            ".config/fzf/fzf.zsh".source = files.fzfZsh.outPath;
          };

          config.programs.bash.initExtra = "source ~/.config/fzf/fzf.sh";

          # fzf.zsh (ZLE widgets/bindkey) is zsh-only, so it isn't sourced into bash.
          config.wrappers.zsh.extraInitContent = ''
            source ~/.config/fzf/fzf.sh
            source ~/.config/fzf/fzf.zsh
          '';
        };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkFzf { inherit pkgs; };
        }
      );
    };
}
