{ config, lib, pkgs, ... }: {
  home.packages = [
    pkgs._7zz # archive entry/method listing for the properties panel
    pkgs.ffmpeg-headless # ffprobe, for media duration/codec in the properties panel
  ];

  programs.yazi = {
    enableZshIntegration = config.dotfiles.shell.program == "zsh";
    enableFishIntegration = config.dotfiles.shell.program == "fish";
    enableNushellIntegration = config.dotfiles.shell.program == "nushell";
    shellWrapperName = "y";

    plugins = {
      full-border = pkgs.yaziPlugins.full-border;
      bookmarks = pkgs.yaziPlugins.bookmarks;
      toggle-pane = pkgs.yaziPlugins.toggle-pane;
      properties = ./yazi/properties.yazi;
      places = ./yazi/places.yazi;
      piper = pkgs.yaziPlugins.piper;
    };

    initLua = ./yazi/init.lua;

    # Stylix's yazi target (modules/yazi/hm.nix) paints which.mask with a
    # solid base02 background for legibility. That's an explicit color, not
    # the terminal's default background, so Ghostty's opacity.terminal only
    # applies to the rest of the UI - the which-key popup renders as an
    # opaque box against everything else's translucency. mkForce is needed
    # since stylix's target sets the same leaf at normal priority too.
    theme.which.mask = lib.mkForce { };

    settings = {
      mgr = {
        ratio = [
          0
          3
          6
        ];
        linemode = "perm_mtime";
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

    keymap = {
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
          desc = "Toggle the quickbar (favorites/bookmarks/drives/recents/tabs)";
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
      ];
    };
  };
}
