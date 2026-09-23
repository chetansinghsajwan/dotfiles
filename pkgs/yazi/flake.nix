{
  description = "yazi, wrapped with its config, plugins, theme, and shell integration baked in";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      forEachSystem =
        f:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ] f;

      # Static base16 -> yazi theme mapping (see theme.toml), taken from
      # tinted-theming/base16-yazi's templates/default.mustache (the same
      # template Stylix's own yazi target renders through). Only the
      # @baseNN@/@syntectTheme@ placeholders are per-build - substituted
      # below from whatever base16 palette/syntect theme is passed to
      # mkYazi.
      themeTemplate = builtins.readFile ./theme.toml;

      # This repo's own yazi customization, baked in as the default so a
      # bare `mkYazi { inherit pkgs lib; colors = ...; syntectTheme = ...;
      # }` already produces the fully configured tool. settings/keymap/
      # plugins stay overridable (merged over these via recursiveUpdate);
      # initLua/./properties.yazi/./places.yazi/./linemode-toggle.yazi are
      # this repo's own Lua, shipped as files alongside this flake instead
      # of referenced from home-manager.
      defaultSettings = {
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

        # yazi's own default open.rules already route text/*, json, and
        # empty files to the "edit" opener (and everything else -
        # binaries, images, archives - elsewhere), so overriding what
        # "edit" runs is enough: no need to duplicate that mime matching
        # with custom rules, and nothing that isn't genuinely text ever
        # reaches op.
        # %s (not "$0"/"$@" - that's stale docs for an older yazi; the
        # actual template syntax is %-prefixed and already shell-quotes
        # the path) expands to the open action's target file(s). Without
        # spread=true, yazi chunks a multi-file open into one invocation
        # per file, so %s here is always exactly the single file op
        # expects.
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
              # JSON reports as application/json, not text/*, so it needs
              # its own rule to pick up pv/bat's line numbers instead of
              # yazi's jq previewer.
              mime = "application/{json,ndjson}";
              run = ''piper -- pv "$1"'';
            }
          ];

          # Background metadata for the properties panel's type-specific
          # row.
          prepend_fetchers = [
            {
              # yazi's own mime sniffer reports these without the "x-"
              # IANA prefix (e.g. "application/7z-compressed", not
              # "application/x-7z-compressed") — both forms are listed
              # since that's undocumented and could vary by yazi version.
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

      defaultKeymap = {
        mgr.prepend_keymap = [
          {
            on = [
              "p"
              "p"
            ];
            run = "plugin toggle-pane min-preview";
            desc = "Toggle the preview pane";
          }
          {
            on = [
              "p"
              "q"
            ];
            run = "plugin places toggle";
            desc = "Toggle the quickbar (favorites/bookmarks/drives/recents)";
          }
          {
            on = [
              "p"
              "m"
            ];
            run = "plugin properties toggle";
            desc = "Toggle the file metadata panel";
          }
          {
            on = [
              "b"
              "s"
            ];
            run = "plugin bookmarks save";
            desc = "Save current position as a bookmark";
          }
          {
            on = [ "'" ];
            run = "plugin bookmarks jump";
            desc = "Jump to a bookmark";
          }
          {
            on = [
              "b"
              "d"
            ];
            run = "plugin bookmarks delete";
            desc = "Delete a bookmark";
          }
          {
            on = [
              "b"
              "D"
            ];
            run = "plugin bookmarks delete_all";
            desc = "Delete all bookmarks";
          }
          {
            on = [ "?" ];
            run = "help";
            desc = "Open help";
          }

          # yazi's default { / } bindings run "tab_swap -1"/"tab_swap 1" -
          # a raw numeric offset, which clamps at the first/last tab
          # instead of wrapping (silently does nothing past the ends).
          # Passing the step as a string ("prev"/"next") instead of a
          # number hits a different code path in yazi's Step::add that
          # wraps with rem_euclid, so reordering past either end cycles to
          # the other.
          {
            on = [ "{" ];
            run = "tab_swap prev";
            desc = "Swap current tab with previous tab";
          }
          {
            on = [ "}" ];
            run = "tab_swap next";
            desc = "Swap current tab with next tab";
          }

          # Renames yazi's default "create a new tab" from t t to t n, and
          # adds t q to close the current tab (yazi has no default binding
          # for that specifically - only <C-c>, which also quits if it's
          # the last tab). t r (rename tab) is untouched.
          {
            on = [
              "t"
              "n"
            ];
            run = "tab_create --current";
            desc = "Create a new tab in CWD";
          }
          {
            on = [
              "t"
              "q"
            ];
            run = "close";
            desc = "Close the current tab";
          }
          {
            on = [
              "t"
              "t"
            ];
            run = "noop";
          }

          # Replaces yazi's default linemode leader ("m") entries with
          # independent toggles for permissions/owner/size/time instead of
          # the fixed one-at-a-time modes yazi offers, combining whichever
          # are on into one of the linemodes init.lua generates.
          {
            on = [
              "m"
              "p"
            ];
            run = "plugin linemode-toggle toggle_perm";
            desc = "Toggle permissions in the linemode";
          }
          {
            on = [
              "m"
              "t"
            ];
            run = "plugin linemode-toggle toggle_time";
            desc = "Toggle time in the linemode";
          }
          {
            on = [
              "m"
              "o"
            ];
            run = "plugin linemode-toggle toggle_owner";
            desc = "Toggle owner in the linemode";
          }
          {
            on = [
              "m"
              "s"
            ];
            run = "plugin linemode-toggle toggle_size";
            desc = "Toggle size in the linemode";
          }
          # m p/m o/m s are now the real toggles above; only the yazi
          # defaults not being reused (btime, mtime, none) still need
          # neutralizing.
          {
            on = [
              "m"
              "b"
            ];
            run = "noop";
          }
          {
            on = [
              "m"
              "m"
            ];
            run = "noop";
          }
          {
            on = [
              "m"
              "n"
            ];
            run = "noop";
          }
        ];
      };

      defaultPlugins = pkgs: {
        full-border = pkgs.yaziPlugins.full-border;
        bookmarks = pkgs.yaziPlugins.bookmarks;
        toggle-pane = pkgs.yaziPlugins.toggle-pane;
        properties = ./properties.yazi;
        places = ./places.yazi;
        linemode-toggle = ./linemode-toggle.yazi;
        piper = pkgs.yaziPlugins.piper;
      };

      defaultInitLua = ./init.lua;

      mkYazi =
        {
          pkgs,
          lib ? pkgs.lib,
          settings ? { },
          keymap ? { },
          # Path to a Lua file, written verbatim as init.lua. Defaults to
          # defaultInitLua above.
          initLua ? null,
          # Plugins as { <name> = <path>; ... }, merged over
          # defaultPlugins above and symlinked to
          # <config-dir>/plugins/<name>.yazi.
          plugins ? { },
          # Extra packages on PATH, on top of the previewer deps nixpkgs'
          # own pkgs.yazi wrapper bundles by default (see below).
          extraPackages ? [ ],
          # Base16 palette as { base00 = "#hex"; ...; base0F = "#hex"; }
          # (Stylix's `config.lib.stylix.colors.withHashtag` shape). Omit
          # for an unthemed build.
          colors ? null,
          # Path to a .tmTheme file for mgr.syntect_theme (text-preview
          # syntax highlighting). Only used when colors != null.
          syntectTheme ? null,
          # localLib.wrapped.base16.substituteTemplate - see
          # pkgs/helix/flake.nix for why this is a parameter and not a
          # local definition.
          substituteTemplate ? (
            template: replacements:
            builtins.replaceStrings (map (name: "@${name}@") (
              builtins.attrNames replacements
            )) (builtins.attrValues replacements) template
          ),
        }:
        let
          tomlFormat = pkgs.formats.toml { };

          finalSettings = lib.recursiveUpdate defaultSettings settings;
          finalKeymap = lib.recursiveUpdate defaultKeymap keymap;
          finalPlugins = lib.recursiveUpdate (defaultPlugins pkgs) plugins;
          finalInitLua = if initLua == null then defaultInitLua else initLua;

          configFile = tomlFormat.generate "yazi.toml" finalSettings;
          keymapFile = tomlFormat.generate "keymap.toml" finalKeymap;

          themeFile = pkgs.writeText "theme.toml" (
            substituteTemplate themeTemplate (
              colors // { syntectTheme = if syntectTheme == null then "" else toString syntectTheme; }
            )
          );

          configDir = pkgs.runCommand "yazi-config-dir" { } (
            ''
              mkdir -p $out/plugins
              ln -s ${configFile} $out/yazi.toml
              ln -s ${keymapFile} $out/keymap.toml
            ''
            + lib.optionalString (colors != null) ''
              ln -s ${themeFile} $out/theme.toml
            ''
            + ''
              ln -s ${pkgs.writeText "init.lua" (builtins.readFile finalInitLua)} $out/init.lua
            ''
            + lib.concatStrings (
              lib.mapAttrsToList (name: path: ''
                ln -s ${path} $out/plugins/${name}.yazi
              '') finalPlugins
            )
          );

          # Matches the previewer deps nixpkgs' own pkgs.yazi wrapper puts
          # on PATH (resvg/chafa/imagemagick for image previews, poppler
          # for PDF, jq for JSON, file for MIME sniffing, fd/rg/fzf/zoxide
          # for plugins that shell out to them, 7zz/ffmpeg for archive and
          # media metadata) - replicated here since this wraps
          # yazi-unwrapped instead.
          defaultExtraPackages = with pkgs; [
            resvg
            chafa
            imagemagick
            zoxide
            fzf
            ripgrep
            fd
            ffmpeg-headless
            _7zz
            poppler-utils
            jq
            file
          ];
        in
        pkgs.symlinkJoin {
          name = "yazi-wrapped";
          # Wrap yazi-unwrapped, not pkgs.yazi - see pkgs/helix/flake.nix
          # for why (avoids clobbering an existing wrapper's own flags).
          paths = [ pkgs.yazi-unwrapped ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/yazi \
              --set YAZI_CONFIG_HOME "${configDir}" \
              --suffix PATH : ${lib.makeBinPath (defaultExtraPackages ++ extraPackages)}

            # "y" cd-on-exit wrapper: opens yazi, then cds the calling shell
            # to wherever yazi was left in on exit.
            mkdir -p $out/share/yazi-shell
            cp ${./y.zsh} $out/share/yazi-shell/y.zsh
            cp ${./y.fish} $out/share/yazi-shell/y.fish
            cp ${./y.nu} $out/share/yazi-shell/y.nu
          '';
        };
    in
    {
      lib = { inherit mkYazi; };

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
