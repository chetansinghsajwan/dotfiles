{
  config,
  localLib,
  ...
}:
{
  imports = [
    ./keybindings.nix
  ]
  ++ localLib.importDir ./features;

  programs.zed-editor = {
    userSettings = {
      autosave = {
        after_delay = {
          milliseconds = 1000;
        };
      };
      format_on_save = "on";
      auto_update = false;
      confirm_quit = true;
      tab_size = 4;
      remove_trailing_whitespace_on_save = true;
      ensure_final_newline_on_save = true;
      git.inline_blame.enabled = true;

      terminal.shell.program = config.dotfiles.shell.program;
    };
  };
}
