# nix-wrapper-modules doesn't ship a native fzf wrapper module, so this
# bakes this repo's own fzf customization (popup layout, binds, theme,
# picker functions) directly into the wrapped binary - so this one file
# is the complete fzf wrapper. Theming is this module's own
# responsibility end to end: `colors` defaults to this repo's own
# default base16 theme, so a standalone build is themed out of the box
# with no outer config needed at all. Whatever imports this (see
# flake.nix's `homeModules.default`) may still override `colors` with a
# live palette (e.g. Stylix's) when one is available.
{
  config,
  lib,
  pkgs,
  wlib,
  ...
}:
{
  imports = [
    wlib.modules.default

    # Purely so `colors` below can default to config.dotfiles.theme.colors
    # - the same config/default.nix option this repo's home-manager hosts
    # already get, just merged into this wrapper module's own isolated
    # evalModules instead of home-manager's. pkgs/lib/config are already
    # shared module args, so this needs no separate evalModules call or
    # specialArgs threading.
    ../../../config

    # Sets config.colorArgs from config.colors.
    ./theme.nix
  ];

  options.colors = lib.mkOption {
    type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
    default = config.dotfiles.theme.colors;
    defaultText = lib.literalExpression "config.dotfiles.theme.colors";
    description = ''
      base16 palette as { base00 = "#hex"; ...; }, e.g.
      `config.lib.stylix.colors.withHashtag`. Defaults to this repo's own
      config.dotfiles.theme.colors; set to null to leave fzf unthemed
      (its own defaults) instead.
    '';
  };

  options.colorArgs = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = ''
      Value for fzf's --color flag (comma-separated key:value pairs).
      Set by theme.nix from `colors` above.
    '';
  };

  options.histfile = lib.mkOption {
    type = lib.types.str;
    default = "$HOME/.zsh_history";
    description = ''
      Path to zsh's history file, substituted at build time into the
      built fh picker function's source (see constructFiles.fzfSh
      below) - $HISTFILE can be unset in some calling contexts, which
      would otherwise silently fall back to a stale ~/.zsh_history.
      Home-manager overrides this with config.programs.zsh.history.path
      when present; left at this plain $HOME-relative default
      otherwise, expanded by the shell at runtime like zsh's own
      default history location.
    '';
  };

  config = {
    package = lib.mkDefault pkgs.fzf;

    # fd/ripgrep back ff/fs's search; bat/eza back their previews (with
    # bat/eza's own explicit --color/--icons flags spelled out in
    # fzf.sh directly, not depending on pkgs-wrapped's own themed eza).
    # Baking all four into fzf's own PATH here means the picker
    # functions still work on a standalone install that never installed
    # them on its own.
    runtimePkgs = [
      pkgs.fd
      pkgs.ripgrep
      pkgs.bat
      pkgs.eza
    ];

    env.FZF_DEFAULT_OPTS = lib.concatStringsSep " " (
      [
        "--popup 90%"
        "--border rounded"
        "--layout reverse"
        "--margin 1"
        "--padding 1"
        "--preview-window right:60%:noborder"
        "--bind ctrl-a:select-all"
        "--bind alt-k:preview-half-page-up"
        "--bind alt-j:preview-half-page-down"
        "--bind ctrl-/:toggle-preview"
      ]
      ++ lib.optional (config.colorArgs != null) "--color ${config.colorArgs}"
    );

    # fzf.sh's picker functions (ff/fs/fp/fe/fcmd/fssh/fh + the shared
    # __fzf helper) and fzf.zsh's ZLE widgets, baked directly into this
    # package's own output, so a plain `nix profile
    # install`/`home.packages`/`environment.systemPackages` install
    # already carries them - not just a home-manager one. Whatever
    # imports this module (see flake.nix's `homeModules.default`) still
    # decides which shell to actually wire the sourcing into.
    constructFiles.fzfSh = {
      relPath = "share/fzf/fzf.sh";
      content = builtins.replaceStrings [ "@histfile@" ] [ config.histfile ] (
        builtins.readFile ../resources/fzf.sh
      );
    };
    constructFiles.fzfZsh = {
      relPath = "share/fzf/fzf.zsh";
      content = builtins.readFile ../resources/fzf.zsh;
    };
  };
}
