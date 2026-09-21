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

    initLua = ./yazi/init.lua;

    settings = {
      mgr = {
        ratio = [ 0 3 6 ];
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
