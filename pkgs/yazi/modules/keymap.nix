# This repo's own yazi keybinding customization.
{
  config.settings.keymap.mgr.prepend_keymap = [
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
}
