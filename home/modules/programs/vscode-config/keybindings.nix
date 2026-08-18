[
  {
    key = "ctrl+p";
    command = "workbench.action.showCommands";
  }
  {
    key = "ctrl+p";
    command = "workbench.action.quickOpenNavigateNextInFilePicker";
    when = "inFilesPicker && inQuickOpen";
  }
  {
    key = "ctrl+shift+p";
    command = "workbench.action.quickOpenNavigatePreviousInFilePicker";
    when = "inFilesPicker && inQuickOpen";
  }
  {
    key = "ctrl+;";
    command = "workbench.action.tasks.runTask";
  }
  # {
  #     key = "ctrl+o";
  #     command = "workbench.action.quickOpen";
  # }
  # {
  #     key = "ctrl+alt c";
  # }
  # {
  #     key = "ctrl+alt e";
  #     command = "workbench.view.explorer";
  # }
  # {
  #     key = "ctrl+alt g";
  #     command = "workbench.view.scm";
  # }
  # {
  #     key = "ctrl+alt x";
  #     command = "workbench.view.extensions";
  # }
  # {
  #     key = "ctrl+alt o";
  #     command = "workbench.action.output.toggleOutput";
  #     when = "workbench.panel.output.active";
  # }
  # {
  #     key = "ctrl+alt shift+o";
  #     command = "workbench.action.showOutputChannels";
  #     when = "workbench.panel.output.active";
  # }
  # {
  #     key = "ctrl+alt m";
  #     command = "workbench.actions.view.problems";
  #     when = "workbench.panel.markers.view.active";
  # }
  # {
  #     key = "ctrl+alt p";
  #     command = "workbench.action.showCommands";
  # }
  # {
  #     key = "ctrl+alt f";
  #     command = "workbench.action.quickOpen";
  # }
  # {
  #     key = "ctrl+alt b left";
  #     command = "workbench.action.toggleSidebarVisibility";
  # }
  # {
  #     key = "ctrl+alt b down";
  #     command = "workbench.action.togglePanel";
  # }
  # {
  #     key = "ctrl+alt b right";
  #     command = "workbench.action.toggleAuxiliaryBar";
  # }
  # {
  #     key = "ctrl+alt b 1";
  #     command = "workbench.action.toggleSidebarVisibility";
  # }
  # {
  #     key = "ctrl+alt b 2";
  #     command = "workbench.action.togglePanel";
  # }
  # {
  #     key = "ctrl+alt b 3";
  #     command = "workbench.action.toggleAuxiliaryBar";
  # }
  {
    key = "alt+left";
    command = "editor.action.outdentLines";
    when = "editorTextFocus && !editorReadonly";
  }
  {
    key = "alt+right";
    command = "editor.action.indentLines";
    when = "editorTextFocus && !editorReadonly";
  }

  # ---------------------------------------------------------------------------------------------
  # Disable default keybindings
  # ---------------------------------------------------------------------------------------------

  # {
  #     key = "ctrl+shift+e";
  # }
  # {
  #     key = "ctrl+shift+g";
  # }
  {
    key = "ctrl+k ctrl+h";
    command = "-workbench.action.output.toggleOutput";
  }
  {
    key = "up";
    command = "-selectPrevSuggestion";
    when = "suggestWidgetMultipleSuggestions && suggestWidgetVisible && textInputFocus || suggestWidgetVisible && textInputFocus && !suggestWidgetHasFocusedSuggestion";
  }
  {
    key = "down";
    command = "-selectNextSuggestion";
    when = "suggestWidgetMultipleSuggestions && suggestWidgetVisible && textInputFocus || suggestWidgetVisible && textInputFocus && !suggestWidgetHasFocusedSuggestion";
  }
  {
    key = "ctrl+[";
    command = "-editor.action.outdentLines";
    when = "editorTextFocus && !editorReadonly";
  }
  # {
  #     key = "ctrl+shift+m";
  # }
  {
    key = "ctrl+shift+p";
    command = "-workbench.action.quickOpenNavigatePreviousInFilePicker";
    when = "inFilesPicker && inQuickOpen";
  }
  {
    key = "ctrl+shift+p";
    command = "-workbench.action.showCommands";
  }
]
