# colors -> yazi theme.toml sections, ported from stylix's own yazi target
# (modules/yazi/hm.nix), since wrapping yazi via nix-wrapper-modules bypasses
# `programs.yazi` and so never runs Stylix's target for it.
#
# `colors`: a base16 palette as { base00 = "#hex"; ...; cyan = "#hex"; ... }
# (e.g. `config.lib.stylix.colors.withHashtag`), or null to leave yazi's
# theme at its own defaults.
colors:
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
  }
