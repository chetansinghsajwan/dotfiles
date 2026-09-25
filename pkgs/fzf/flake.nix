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

      mkTheme = import ./theme.nix;
      wrapperModule = ./module.nix;
    in
    {
      lib = {
        inherit mkTheme;

        mkFzf =
          {
            pkgs,
            colors ? null,
          }:
          wrappers.lib.evalPackage [
            { inherit pkgs; }
            wrapperModule
            { config.colorArgs = mkTheme colors; }
          ];
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
          pkgs,
          ...
        }:
        {
          imports = [
            (wrappers.lib.getInstallModule {
              name = "fzf";
              value = wrapperModule;
            })
          ];

          config.wrappers.fzf.colorArgs = mkTheme (
            lib.attrByPath [
              "lib"
              "stylix"
              "colors"
              "withHashtag"
            ] null config
          );

          # bat stays on home-manager's own `programs.bat` (not plain
          # home.packages) so stylix's bat target still fires - it
          # generates the "base16-stylix" bat theme that both delta's
          # syntax-theme and pv's bat-based previews depend on.
          config.programs.bat.enable = true;

          config.home.packages = [
            pkgs.fd
            pkgs.ripgrep
          ];

          config.home.file = {
            # fh's history file path is baked in from zsh's own history
            # option at build time instead of read from $HISTFILE at call
            # time, so it can't silently fall back to a stale/wrong file
            # in a context where $HISTFILE isn't set.
            ".config/fzf/fzf.sh".text =
              builtins.replaceStrings
                [ "@histfile@" ]
                [
                  config.programs.zsh.history.path
                ]
                (builtins.readFile ./fzf.sh);

            ".config/fzf/fzf.zsh".source = ./fzf.zsh;
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
          default = wrappers.lib.evalPackage [
            { inherit pkgs; }
            wrapperModule
          ];
        }
      );
    };
}
