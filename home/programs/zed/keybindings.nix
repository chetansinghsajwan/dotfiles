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
            {
                context = "Editor";
                bindings = {
                    "ctrl-up" = [
                        "workspace::SendKeystrokes"
                        "up up up up up up up up up up"
                    ];
                    "ctrl-down" = [
                        "workspace::SendKeystrokes"
                        "down down down down down down down down down down"
                    ];
                    "ctrl-left" = "editor::MoveToPreviousWordStart";
                    "ctrl-right" = "editor::MoveToNextWordEnd";
                    "ctrl-shift-up" = [
                        "workspace::SendKeystrokes"
                        "shift-up shift-up shift-up shift-up shift-up shift-up shift-up shift-up shift-up shift-up"
                    ];
                    "ctrl-shift-down" = [
                        "workspace::SendKeystrokes"
                        "shift-down shift-down shift-down shift-down shift-down shift-down shift-down shift-down shift-down shift-down"
                    ];
                    "ctrl-shift-left" = "editor::SelectToPreviousWordStart";
                    "ctrl-shift-right" = "editor::SelectToNextWordEnd";
                    "ctrl-backspace" = "editor::DeleteToPreviousWordStart";
                    "ctrl-delete" = "editor::DeleteToNextWordEnd";
                };
            }
        ];
    };
}
