_: {
  programs.zed-editor = {
    userKeymaps = [
      {
        context = "Workspace";
        bindings = {
          "ctrl-n" = "workspace::NewFile";
          "ctrl-p" = "command_palette::Toggle";
          "ctrl-shift-p" = null;
          "ctrl-e" = "file_finder::Toggle";
          "ctrl-shift-e" = "project_panel::ToggleFocus";
          "ctrl-shift-i" = "editor::Format";
        };
      }
    ];
  };
}
