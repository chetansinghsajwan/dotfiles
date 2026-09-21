{ config, pkgs, ... }: {
  programs.yazi = {
    enableZshIntegration = config.dotfiles.shell.program == "zsh";
    enableFishIntegration = config.dotfiles.shell.program == "fish";
    enableNushellIntegration = config.dotfiles.shell.program == "nushell";
    shellWrapperName = "y";

    plugins = {
      full-border = pkgs.yaziPlugins.full-border;
      bookmarks = pkgs.yaziPlugins.bookmarks;
      properties = ./yazi/properties.yazi;
      piper = pkgs.yaziPlugins.piper;
    };

    initLua = ''
      require("full-border"):setup()
      require("bookmarks"):setup()
      require("properties"):setup()

      -- Combined "permissions + relative mtime" linemode for the files pane.
      -- Permissions are rendered as three spaced, colorized rwx triplets
      -- (owner in full color, group/other dimmed, special bits highlighted)
      -- instead of a raw `ls -la` string, and mtime is a relative duration.
      local function perm_span(ch, is_owner)
        if ch == "s" or ch == "S" or ch == "t" or ch == "T" then
          return ui.Span(ch):fg("magenta"):bold()
        end
        if not is_owner then
          return ui.Span(ch):fg("darkgray")
        end
        if ch == "r" then
          return ui.Span(ch):fg("green")
        elseif ch == "w" then
          return ui.Span(ch):fg("yellow")
        elseif ch == "x" then
          return ui.Span(ch):fg("red")
        else
          return ui.Span(ch):fg("darkgray")
        end
      end

      local function perm_spans(cha)
        local bits = cha and cha:perm()
        if not bits or #bits < 10 then
          return { ui.Span("---------"):fg("darkgray") }
        end
        bits = bits:sub(2) -- drop the leading type char (d/l/-)

        local spans = {}
        for i = 1, 9 do
          spans[#spans + 1] = perm_span(bits:sub(i, i), i <= 3)
          if i == 3 or i == 6 then
            spans[#spans + 1] = ui.Span(" ")
          end
        end
        return spans
      end

      local function relative_time(time)
        time = math.floor(time or 0)
        if time == 0 then
          return "-"
        end

        local diff = os.time() - time
        if diff < 60 then
          return "now"
        elseif diff < 3600 then
          return string.format("%dm ago", math.floor(diff / 60))
        elseif diff < 86400 then
          return string.format("%dh ago", math.floor(diff / 3600))
        elseif diff < 86400 * 30 then
          return string.format("%dd ago", math.floor(diff / 86400))
        elseif diff < 86400 * 365 then
          return string.format("%dmo ago", math.floor(diff / (86400 * 30)))
        else
          return os.date("%Y", time)
        end
      end

      function Linemode:perm_mtime()
        local spans = perm_spans(self._file.cha)
        spans[#spans + 1] = ui.Span("  ")
        local time = relative_time(self._file.cha and self._file.cha.mtime)
        spans[#spans + 1] = ui.Span(string.format("%8s", time)):fg("darkgray")
        return spans
      end
    '';

    settings = {
      mgr = {
        ratio = [ 0 4 6 ];
        linemode = "perm_mtime";
      };

      plugin = {
        prepend_previewers = [
          {
            mime = "text/*";
            run = ''piper -- bat --color=always --style=numbers --paging=never "$1"'';
          }
          {
            # JSON reports as application/json, not text/*, so it needs its
            # own rule to pick up bat's line numbers instead of yazi's jq previewer.
            mime = "application/{json,ndjson}";
            run = ''piper -- bat --color=always --style=numbers --paging=never "$1"'';
          }
        ];
      };
    };

    keymap = {
      mgr.prepend_keymap = [
        {
          on = [ "m" ];
          run = "plugin bookmarks save";
          desc = "Save current position as a bookmark";
        }
        {
          on = [ "'" ];
          run = "plugin bookmarks jump";
          desc = "Jump to a bookmark";
        }
        {
          on = [ "b" "d" ];
          run = "plugin bookmarks delete";
          desc = "Delete a bookmark";
        }
        {
          on = [ "b" "D" ];
          run = "plugin bookmarks delete_all";
          desc = "Delete all bookmarks";
        }
      ];
    };
  };
}
