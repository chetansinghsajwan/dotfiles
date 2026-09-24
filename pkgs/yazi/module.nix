# `colors`: a base16 palette as { base00 = "#hex"; ...; cyan = "#hex"; ... }
# (e.g. `config.lib.stylix.colors.withHashtag`), or null to leave yazi's
# theme at its own defaults.
{
  colors ? null,
}:
{
  config,
  pkgs,
  ...
}:
let
  # Ported from stylix's own yazi target (modules/yazi/hm.nix), since
  # wrapping yazi via nix-wrapper-modules bypasses `programs.yazi` and so
  # never runs Stylix's target for it.
  theme =
    if colors == null then
      { }
    else
      with colors;
      let
        mkFg = fg: { inherit fg; };
        mkBg = bg: { inherit bg; };
        mkBoth = fg: bg: { inherit fg bg; };
        mkSame = c: mkBoth c c;
        mkRule = mime: fg: { inherit mime fg; };
      in
      {
        mgr = {
          cwd = mkFg cyan;
          find_keyword = mkFg green // {
            bold = true;
          };
          find_position = mkFg magenta;
          marker_selected = mkSame yellow;
          marker_copied = mkSame green;
          marker_cut = mkSame red;
          border_style = mkFg base04;

          count_copied = mkBoth base00 green;
          count_cut = mkBoth base00 red;
          count_selected = mkBoth base00 yellow;
        };

        indicator = rec {
          current = mkBg base02 // {
            bold = true;
          };
          preview = current;
        };

        tabs = {
          active = mkBoth base00 blue // {
            bold = true;
          };
          inactive = mkBoth blue base01;
        };

        mode = {
          normal_main = mkBoth base00 blue // {
            bold = true;
          };
          normal_alt = mkBoth blue base00;
          select_main = mkBoth base00 green // {
            bold = true;
          };
          select_alt = mkBoth green base00;
          unset_main = mkBoth base00 brown // {
            bold = true;
          };
          unset_alt = mkBoth brown base00;
        };

        status = {
          progress_label = mkBoth base05 base00;
          progress_normal = mkBoth base05 base00;
          progress_error = mkBoth red base00;
          perm_type = mkFg blue;
          perm_read = mkFg yellow;
          perm_write = mkFg red;
          perm_exec = mkFg green;
          perm_sep = mkFg cyan;
        };

        pick = {
          border = mkFg blue;
          active = mkFg magenta;
          inactive = mkFg base05;
        };

        input = {
          border = mkFg blue;
          title = mkFg base05;
          value = mkFg base05;
          selected = mkBg base03;
        };

        cmp = {
          border = mkFg blue;
          active = mkBoth magenta base03;
          inactive = mkFg base05;
        };

        tasks = {
          border = mkFg blue;
          title = mkFg base05;
          hovered = mkBoth base05 base03;
        };

        # Left empty (not just re-themed) rather than Stylix's own solid
        # base02 background: that's an explicit color, not the terminal's
        # default background, so Ghostty's opacity.terminal only applies
        # to the rest of the UI - a solid mask would render the which-key
        # popup as an opaque box against everything else's translucency.
        which = {
          mask = { };
          cand = mkFg cyan;
          rest = mkFg brown;
          desc = mkFg base05;
          separator_style = mkFg base04;
        };

        help = {
          on = mkFg magenta;
          run = mkFg cyan;
          desc = mkFg base05;
          hovered = mkBoth base05 base03;
          footer = mkFg base05;
        };

        # https://github.com/sxyazi/yazi/blob/main/yazi-config/preset/theme.toml
        filetype.rules = [
          (mkRule "image/*" cyan)
          (mkRule "video/*" yellow)
          (mkRule "audio/*" yellow)

          (mkRule "application/zip" magenta)
          (mkRule "application/gzip" magenta)
          (mkRule "application/tar" magenta)
          (mkRule "application/bzip" magenta)
          (mkRule "application/bzip2" magenta)
          (mkRule "application/7z-compressed" magenta)
          (mkRule "application/rar" magenta)
          (mkRule "application/xz" magenta)

          (mkRule "application/doc" green)
          (mkRule "application/pdf" green)
          (mkRule "application/rtf" green)
          (mkRule "application/vnd.*" green)

          {
            url = "*/";
            fg = blue;
            bold = true;
          }
          (mkRule "*" base05)
        ];

        icon =
          let
            mkIcon = text: fg: { inherit text fg; };
            mkDirIcon =
              name: text: fg:
              mkIcon text fg // { inherit name; };
            mkCondIcon =
              cond: text: fg:
              mkIcon text fg // { "if" = cond; };
          in
          {
            dirs = [
              (mkDirIcon ".config" "" orange)
              (mkDirIcon ".git" "" cyan)
              (mkDirIcon ".github" "" blue)
              (mkDirIcon ".npm" "" blue)
              (mkDirIcon "Desktop" "" cyan)
              (mkDirIcon "Development" "" cyan)
              (mkDirIcon "Documents" "" cyan)
              (mkDirIcon "Downloads" "" cyan)
              (mkDirIcon "Library" "" cyan)
              (mkDirIcon "Movies" "" cyan)
              (mkDirIcon "Music" "" cyan)
              (mkDirIcon "Pictures" "" cyan)
              (mkDirIcon "Public" "" cyan)
              (mkDirIcon "Videos" "" cyan)
            ];

            conds = [
              (mkCondIcon "orphan" "" base05)
              (mkCondIcon "link" "" base04)
              (mkCondIcon "block" "" yellow)
              (mkCondIcon "char" "" yellow)
              (mkCondIcon "fifo" "" yellow)
              (mkCondIcon "sock" "" yellow)
              (mkCondIcon "sticky" "" yellow)
              (mkCondIcon "dummy" "" red)

              (mkCondIcon "dir" "" blue)
              (mkCondIcon "exec" "" green)
              (mkCondIcon "!dir" "" base05)
            ];
          };
      };
in
{
  config = {
    plugins = {
      full-border = pkgs.yaziPlugins.full-border;
      bookmarks = pkgs.yaziPlugins.bookmarks;
      toggle-pane = pkgs.yaziPlugins.toggle-pane;
      properties = ./properties.yazi;
      places = ./places.yazi;
      linemode-toggle = ./linemode-toggle.yazi;
      piper = pkgs.yaziPlugins.piper;
    };

    constructFiles.init = {
      relPath = "${config.binName}-config/init.lua";
      output = config.generatedConfig.output;
      content = builtins.readFile ./init.lua;
    };

    settings.theme = theme;

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

    settings.keymap.mgr.prepend_keymap = [
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

      # yazi's default { / } bindings run "tab_swap -1"/"tab_swap 1" - a
      # raw numeric offset, which clamps at the first/last tab instead
      # of wrapping (silently does nothing past the ends). Passing the
      # step as a string ("prev"/"next") instead of a number hits a
      # different code path in yazi's Step::add that wraps with
      # rem_euclid, so reordering past either end cycles to the other.
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
}
