# nix-wrapper-modules wrapper module: pulls in nix-wrapper-modules' own
# native yazi module (settings/keymap/theme/vfs/package options,
# constructFiles, package default, etc.) plus this repo's own yazi
# customization (plugins, keymap, settings, theme) on top - so this one
# file is the complete yazi wrapper, and callers only ever need to
# reference it, not also list `wrappers.wrapperModules.yazi` separately.
# Theming is this module's own responsibility end to end: `colors`
# defaults to this repo's own default base16 theme, so a standalone
# build is themed out of the box with no outer config needed at all.
# Whatever imports this (see flake.nix's `homeModules.default`) may
# still override `colors` with a live palette (e.g. Stylix's) when one
# is available.
{
  config,
  lib,
  pkgs,
  wlib,
  # The built `op`/`pv` packages (pkgs/op and pkgs/pv's own mkOp/mkPv),
  # threaded in via specialArgs from flake.nix - neither is in nixpkgs,
  # and a plain wrapper module can't reach another package's flake output
  # on its own.
  opPkg,
  pvPkg,
  ...
}:
{
  imports = [
    wlib.wrapperModules.yazi

    # Purely so `colors` below can default to config.dotfiles.theme.colors
    # - the same config/default.nix option this repo's home-manager hosts
    # already get, just merged into this wrapper module's own isolated
    # evalModules instead of home-manager's. pkgs/lib/config are already
    # shared module args, so this needs no separate evalModules call or
    # specialArgs threading.
    ../../../config

    # Sets config.settings.theme from config.colors.
    ./theme.nix

    # This repo's own yazi keybindings.
    ./keymap.nix
  ];

  options.colors = lib.mkOption {
    type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
    default = config.dotfiles.theme.colors;
    defaultText = lib.literalExpression "config.dotfiles.theme.colors";
    description = ''
      base16 palette as { base00 = "#hex"; ...; cyan = "#hex"; ... }, e.g.
      `config.lib.stylix.colors.withHashtag`. Defaults to this repo's own
      config.dotfiles.theme.colors; set to null to leave yazi unthemed
      (its own defaults) instead.
    '';
  };

  config = {
    # 7zz (archive listing) and ffprobe (media duration/codec) back the
    # properties panel; op is what settings.yazi.opener.edit runs, pv is
    # what the piper previewers below run. Baking all four into yazi's
    # own PATH here means every consumer gets them for free instead of
    # having to add them to home.packages separately - and, for op/pv
    # specifically, means yazi's "Edit" keybinding and text/CSV previews
    # still work on a standalone install that never installed them on
    # its own.
    runtimePkgs = [
      pkgs._7zz
      pkgs.ffmpeg-headless
      opPkg
      pvPkg
    ];

    plugins = {
      full-border = pkgs.yaziPlugins.full-border;
      bookmarks = pkgs.yaziPlugins.bookmarks;
      toggle-pane = pkgs.yaziPlugins.toggle-pane;
      properties = ../plugins/properties.yazi;
      places = ../plugins/places.yazi;
      linemode-toggle = ../plugins/linemode-toggle.yazi;
      piper = pkgs.yaziPlugins.piper;
    };

    constructFiles.init = {
      relPath = "${config.binName}-config/init.lua";
      output = config.generatedConfig.output;
      content = builtins.readFile ../resources/init.lua;
    };

    # y.sh/y.fish/y.nu (the "cd to wherever you were when you quit yazi"
    # shell function) baked directly into this package's own output, so a
    # plain `nix profile install`/`home.packages`/`environment.systemPackages`
    # install already carries them - not just a home-manager one. Whatever
    # imports this module (see flake.nix's `homeModules.default`) still
    # decides which shell to actually wire the sourcing into. y.sh (not
    # y.zsh) since it's plain, portable shell - nothing zsh-exclusive.
    constructFiles.ySh = {
      relPath = "share/yazi/y.sh";
      content = builtins.readFile ../resources/y.sh;
    };
    constructFiles.yFish = {
      relPath = "share/yazi/y.fish";
      content = builtins.readFile ../resources/y.fish;
    };
    constructFiles.yNu = {
      relPath = "share/yazi/y.nu";
      content = builtins.readFile ../resources/y.nu;
    };

    settings.yazi = {
      mgr = {
        ratio = [
          0
          3
          6
        ];
        linemode = "perm_time";
      };

      # yazi's own defaults (600x900) cap the cached preview image below
      # the preview pane's actual pixel area on most displays, so images
      # render smaller than the pane even though the aspect-ratio-
      # preserving fit itself is correct. Raise the cap so images can
      # actually use the space they're given. Requires `ya cache clear`
      # to apply to already-cached previews.
      preview = {
        max_width = 1920;
        max_height = 1200;
      };

      # yazi's own default open.rules already route text/*, json, and empty
      # files to the "edit" opener (and everything else - binaries, images,
      # archives - elsewhere), so overriding what "edit" runs is enough:
      # no need to duplicate that mime matching with custom rules, and
      # nothing that isn't genuinely text ever reaches op.
      # %s (not "$0"/"$@" - that's stale docs for an older yazi; the actual
      # template syntax is %-prefixed and already shell-quotes the path)
      # expands to the open action's target file(s). Without spread=true,
      # yazi chunks a multi-file open into one invocation per file, so %s
      # here is always exactly the single file op expects.
      opener.edit = [
        {
          run = "op %s";
          block = true;
          desc = "Edit";
        }
      ];

      plugin = {
        prepend_previewers = [
          {
            # pv routes CSV/TSV to tidy-viewer (column-aligned) and
            # everything else text-like to bat, so this one rule covers
            # both plain text and tabular data.
            mime = "text/*";
            run = ''piper -- pv "$1"'';
          }
          {
            # JSON reports as application/json, not text/*, so it needs its
            # own rule to pick up pv/bat's line numbers instead of yazi's jq previewer.
            mime = "application/{json,ndjson}";
            run = ''piper -- pv "$1"'';
          }
        ];

        # Background metadata for the properties panel's type-specific row.
        prepend_fetchers = [
          {
            # yazi's own mime sniffer reports these without the "x-" IANA
            # prefix (e.g. "application/7z-compressed", not
            # "application/x-7z-compressed") — both forms are listed since
            # that's undocumented and could vary by yazi version.
            mime = "application/{zip,tar,x-tar,7z-compressed,x-7z-compressed,gzip,x-gzip,bzip,bzip2,x-bzip,x-bzip2,xz,x-xz,zstd,rar,x-rar,x-rar-compressed,vnd.rar}";
            run = "properties archive";
            group = "properties-archive";
          }
          {
            mime = "text/*";
            run = "properties csv";
            group = "properties-csv";
          }
          {
            mime = "image/*";
            run = "properties image";
            group = "properties-image";
          }
          {
            mime = "video/*";
            run = "properties media";
            group = "properties-media";
          }
          {
            mime = "audio/*";
            run = "properties media";
            group = "properties-media";
          }
        ];
      };
    };
  };
}
