{
    config,
    lib,
    pkgs,
    ...
}:
{
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
            linemode-toggle = ./yazi/linemode-toggle.yazi;
            piper = pkgs.yaziPlugins.piper;
            # The stock plugin drops the sign colour on the hovered row; keep it styled.
            git = pkgs.yaziPlugins.git.overrideAttrs (old: {
                postPatch = (old.postPatch or "") + ''
                    substituteInPlace git.yazi/main.lua --replace-fail "elseif self._file.is_hovered then" "elseif false then"
                '';
            });
        };

        initLua = ./yazi/init.lua;

        # Stylix's yazi target (modules/yazi/hm.nix) paints which.mask with a
        # solid base02 background for legibility. That's an explicit color, not
        # the terminal's default background, so Ghostty's opacity.terminal only
        # applies to the rest of the UI - the which-key popup renders as an
        # opaque box against everything else's translucency. mkForce is needed
        # since stylix's target sets the same leaf at normal priority too.
        theme.which.mask = lib.mkForce { };

        # Row highlight. Stylix paints it base02 (same as the panels, so barely
        # visible); base03 is a step lighter. mkForce since Stylix sets the same
        # leaf at normal priority.
        theme.indicator =
            let
                colors = config.lib.stylix.colors;
                # Muted blue: 25% base0D over base00, so the usual text colours stay
                # readable (a solid base0D bar is too bright for that).
                channel =
                    c:
                    let
                        mixed = (lib.toInt colors."base0D-rgb-${c}") * 25 + (lib.toInt colors."base00-rgb-${c}") * 75;
                    in
                    lib.fixedWidthString 2 "0" (lib.toHexString (mixed / 100));
                bg = lib.mkForce "#${channel "r"}${channel "g"}${channel "b"}";
            in
            {
                current.bg = bg;
                preview.bg = bg;
            };

        # Fixed-width (1 cell) git signs. The plugin returns no marker at all for
        # clean/unknown files, which shifts the column, so give those a blank cell.
        theme.git = {
            unknown_sign = " ";
            clean_sign = " ";
            ignored_sign = "!";
            untracked_sign = "?";
            unstaged_sign = "M";
            staged_sign = "+";
            added_sign = "A";
            deleted_sign = "D";
            updated_sign = "U";
        };

        settings = {
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
                        # Folders: pv lists them with eza instead of yazi's built-in
                        # folder previewer.
                        mime = "folder/*";
                        run = ''piper -- pv "$1"'';
                    }
                    {
                        # JSON reports as application/json, not text/*, so it needs its
                        # own rule to pick up pv/bat's line numbers instead of yazi's jq previewer.
                        mime = "application/{json,ndjson}";
                        run = ''piper -- pv "$1"'';
                    }
                ];

                # Background metadata for the properties panel's type-specific row,
                # plus git status markers for the files pane.
                prepend_fetchers = [
                    {
                        group = "git";
                        url = "*";
                        run = "git";
                    }
                    {
                        group = "git";
                        url = "*/";
                        run = "git";
                    }
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
    };
}
