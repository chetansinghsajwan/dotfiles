_:
let
  # Helper function to flatten nested attribute sets into dot-notation keys
  # Example: {a.b.c = 1; d = 2} -> ["a.b.c" "d"]
  flattenAttrs =
    prefix: attrs:
    builtins.concatMap (
      key:
      let
        value = attrs.${key};
        fullKey = if prefix == "" then key else "${prefix}.${key}";
      in
      if builtins.isAttrs value && !builtins.isFunction value && value != { } then
        flattenAttrs fullKey value
      else
        [ fullKey ]
    ) (builtins.attrNames attrs);

  # All VSCode settings organized by category
  userSettings = {

    # ----------------------------------------------------------------------------------------------
    # Editor settings
    # ----------------------------------------------------------------------------------------------

    # Highlight the active indentation guide (the indent guides at the stack of the current cursor position)
    "editor.guides.highlightActiveIndentation" = true;

    # Show Code Lens which refers to inline visibility of object references, like the number of implementations of an interface
    "editor.codeLens" = true;

    # Highlight the guides (vertical indentation guides) around the active bracket pair
    "editor.guides.bracketPairsHorizontal" = true;

    # Enable bracket pair colorization, meaning each bracket pair gets a different color
    "editor.bracketPairColorization.enabled" = true;

    # Control the cursor blinking animation
    "editor.cursorBlinking" = "phase";

    # Enable smooth caret animation
    "editor.cursorSmoothCaretAnimation" = "on";

    # The style of the cursor when the editor is focused
    "editor.cursorStyle" = "line";

    # Seed the search string with the editor's current word if a selection exists
    "editor.find.seedSearchStringFromSelection" = "selection";

    # Enable font ligatures. Be aware that not all fonts support font ligatures
    "editor.fontLigatures" = true;

    # Render whitespace characters. 'selection' will only show whitespace characters when text is selected
    "editor.minimap.renderCharacters" = false;

    # Slide the horizontal scrollbar when you scroll the minimap. When turned off, the minimap scrolls instead
    "editor.minimap.showSlider" = "always";

    # The space between the top edge of the editor and the first line
    "editor.padding.top" = 10;

    # The space between the bottom edge of the editor and the last line
    "editor.padding.bottom" = 10;

    # Scrolling animation is enabled
    "editor.smoothScrolling" = true;

    # Show inlay type hints when available. When parameter hints are enabled, inlay hints will show for parameters
    "editor.inlayHints.enabled" = "offUnlessPressed";

    # ----------------------------------------------------------------------------------------------
    # Window settings
    # ----------------------------------------------------------------------------------------------

    # # Controls the visibility of the command center
    "window.commandCenter" = false;

    # Controls the style of the window dialogs
    "window.dialogStyle" = "custom";

    # Controls the style of the window title bar (native for system default, custom for VSCode custom titlebar)
    "window.titleBarStyle" = "native";

    # Control visibility of the menu bar (toggle to show on Alt)
    "window.menuBarVisibility" = "toggle";

    # ----------------------------------------------------------------------------------------------
    # Workbench settings
    # ----------------------------------------------------------------------------------------------

    # Enable limits on the number of open editors
    "workbench.editor.limit.enabled" = true;

    # Do not count dirty files when restricting the number of open editors
    "workbench.editor.limit.excludeDirty" = true;

    # The maximum number of editors that can be open at the same time
    "workbench.editor.limit.value" = 8;

    # The startup editor (none: no editor on startup, newUntitledFile: open a new untitled file, welcomePage: open the Welcome page)
    "workbench.startupEditor" = "none";

    # When enabled, will show the Welcome page on startup
    "workbench.tips.enabled" = false;

    # Hide the layout control in the workbench
    "workbench.layoutControl.enabled" = false;

    # ----------------------------------------------------------------------------------------------
    # Files settings
    # ----------------------------------------------------------------------------------------------

    # Controls the auto-save behavior of files
    "files.autoSave" = "afterDelay";

    # The delay (in milliseconds) before auto-saving a file
    "files.autoSaveDelay" = 1000;

    # When enabled, will attempt to guess the character set encoding when opening files
    "files.trimFinalNewlines" = true;

    # When enabled, trailing whitespace is automatically removed when you save a file
    "files.trimTrailingWhitespace" = true;

    # ----------------------------------------------------------------------------------------------
    # Terminal settings
    # ----------------------------------------------------------------------------------------------

    # The style of the cursor in the integrated terminal
    "terminal.integrated.cursorStyle" = "line";

    # The default profile on Windows
    "terminal.integrated.defaultProfile.windows" = "git-bash";

    # The default profile on Linux
    "terminal.integrated.defaultProfile.linux" = "fish";

    # The default profile on macOS
    "terminal.integrated.defaultProfile.osx" = "zsh";

    # Show the tabs of open terminal instances
    "terminal.integrated.tabs.enabled" = true;

    # The profiles of the integrated terminal on Windows
    "terminal.integrated.profiles.windows" = {
      # Git Bash
      "git-bash" = {
        source = "PowerShell";
      };
      # Ubuntu via WSL
      "ubuntu-wsl" = {
        path = "C:\\WINDOWS\\System32\\wsl.exe";
        args = [
          "-d"
          "Ubuntu"
        ];
      };
    };

    # ----------------------------------------------------------------------------------------------
    # Zen mode settings
    # ----------------------------------------------------------------------------------------------

    # Center the layout when in zen mode
    "zenMode.centerLayout" = false;

    # Put the workbench into zen mode
    "zenMode.fullScreen" = true;

    # Hide the line numbers when in zen mode
    "zenMode.hideLineNumbers" = false;

    # ----------------------------------------------------------------------------------------------
    # GitHub Copilot settings
    # ----------------------------------------------------------------------------------------------

    # Enable Copilot to provide edit suggestions
    "github.copilot.nextEditSuggestions.enabled" = true;

    # ----------------------------------------------------------------------------------------------
    # Diff settings
    # ----------------------------------------------------------------------------------------------

    # Render the diff inline, showing insertions and deletions inline side by side
    "diffEditor.renderSideBySide" = true;

    # ----------------------------------------------------------------------------------------------
    # Other settings
    # ----------------------------------------------------------------------------------------------

    # Enable smart scroll in the debug console (when true, ensures that the most recent output is always visible)
    "output.smartScroll.enabled" = true;

    # When enabled, the notifications for extension recommendations will not be shown
    "extensions.ignoreRecommendations" = true;

    # The default view mode of the Problems panel
    "problems.defaultViewMode" = "table";

    # Enable/disable navigation breadcrumbs
    "breadcrumbs.enabled" = true;

    # Show the workspace trust banner
    "security.workspace.trust.banner" = "never";

    # Show the workspace trust dialog when opening a trusted workspace
    "security.workspace.trust.startupPrompt" = "never";

    # Controls how repositories are sorted in the Source Control Repositories view
    "scm.repositories.sortOrder" = "path";

    # Sync keybindings for each platform
    "settingsSync.keybindingsPerPlatform" = false;
  };
in
{
  programs.vscode.userSettings = userSettings // {
    # Automatically generated list of all settings to apply across profiles
    "workbench.settings.applyToAllProfiles" = flattenAttrs "" userSettings;
  };
}
