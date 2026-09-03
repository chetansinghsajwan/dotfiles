{
  # editor settings
  editor.guides.indentation = true;
  editor.guides.highlightActiveIndentation = true;
  editor.codeLens = true;
  editor.guides.bracketPairs = false;
  editor.guides.bracketPairsHorizontal = true;
  editor.bracketPairColorization.enabled = true;
  editor.cursorBlinking = "phase";
  editor.cursorSmoothCaretAnimation = "on";
  editor.cursorStyle = "line";
  editor.cursorWidth = 3;
  editor.dragAndDrop = false;
  editor.find.addExtraSpaceOnTop = false;
  editor.find.seedSearchStringFromSelection = "selection";
  editor.fontFamily = "JetBrainsMono Nerd Font";
  editor.fontLigatures = true;
  editor.fontSize = 14.5;
  editor.fontWeight = "normal";
  editor.formatOnSave = false;
  editor.insertSpaces = true;
  editor.minimap.autohide = "none";
  editor.minimap.renderCharacters = false;
  editor.minimap.showSlider = "always";
  editor.padding.top = 10;
  editor.padding.bottom = 10;
  editor.smoothScrolling = true;
  editor.tabSize = 4;
  editor.inlayHints.enabled = "offUnlessPressed";

  # window settings
  window.autoDetectColorScheme = false;
  window.dialogStyle = "custom";
  window.restoreFullscreen = false;
  window.titleBarStyle = "native";
  window.commandCenter = false;
  window.menuBarVisibility = "toggle";
  window.enableMenuBarMnemonics = false;
  window.customMenuBarAltFocus = false;

  # workbench settings
  workbench.activityBar.location = "default";
  workbench.commandPalette.preserveInput = false;
  workbench.editor.limit.enabled = true;
  workbench.editor.limit.excludeDirty = true;
  workbench.editor.limit.value = 8;
  workbench.panel.defaultLocation = "bottom";
  workbench.panel.opensMaximized = "preserve";
  workbench.reduceMotion = "off";
  workbench.startupEditor = "none";
  workbench.tips.enabled = false;
  workbench.layoutControl.enabled = false;

  # files settings
  files.simpleDialog.enable = true;
  files.trimFinalNewlines = true;
  files.trimTrailingWhitespace = true;

  # terminal settings
  terminal.integrated.cursorBlinking = true;
  terminal.integrated.cursorStyle = "line";
  terminal.integrated.cursorStyleInactive = "none";
  terminal.integrated.cursorWidth = 2;
  terminal.integrated.defaultProfile.windows = "git-bash";
  terminal.integrated.defaultProfile.linux = "fish";
  terminal.integrated.defaultProfile.osx = "zsh";
  terminal.integrated.fontFamily = "JetBrainsMono Nerd Font";
  terminal.integrated.fontSize = 16;
  terminal.integrated.hideOnStartup = "never";
  terminal.integrated.tabs.enabled = true;
  terminal.integrated.profiles.windows = {
    "git-bash" = {
      source = "PowerShell";
    };
    "ubuntu-wsl" = {
      path = "C:\\WINDOWS\\System32\\wsl.exe";
      args = [ "-d" "Ubuntu" ];
    };
  };

  # diff settings
  diffEditor.renderSideBySide = false;

  # output settings
  output.smartScroll.enabled = true;

  # debug settings
  debug.console.fontFamily = "JetBrainsMono Nerd Font";
  debug.console.fontSize = 15;
  debug.toolBarLocation = "docked";

  # extension settings
  extensions.autoCheckUpdates = true;
  extensions.autoUpdate = "on";
  extensions.ignoreRecommendations = true;

  # problems settings
  problems.defaultViewMode = "table";

  # breadcrumbs settings
  breadcrumbs.enabled = true;

  # zenMode settings
  zenMode.centerLayout = false;
  zenMode.fullScreen = true;
  zenMode.hideLineNumbers = false;

  # accessibility settings
  accessibility.dimUnfocused.enabled = true;
  accessibility.dimUnfocused.opacity = 0.7;

  # security settings
  security.workspace.trust.banner = "never";
  security.workspace.trust.startupPrompt = "never";

  # scm settings
  scm.repositories.sortOrder = "path";

  # json settings
  json.format.keepLines = true;

  # settings sync
  settingsSync.keybindingsPerPlatform = false;

  # vim settings
  vim.vimrc.enable = true;
  vim.vimrc.path = "c:\\Users\\ChetanSinghSajwan\\dotfiles\\vimrc";

  markdown-mermaid.darkModeTheme = "vscode";

  # Python settings
  python.terminal.activateEnvironment = false;

  workbench.settings.applyToAllProfiles = [
    # editor settings
    "editor.guides.indentation"
    "editor.guides.highlightActiveIndentation"
    "editor.codeLens"
    "editor.guides.bracketPairs"
    "editor.guides.bracketPairsHorizontal"
    "editor.bracketPairColorization.enabled"
    "editor.cursorBlinking"
    "editor.cursorSmoothCaretAnimation"
    "editor.cursorStyle"
    "editor.cursorWidth"
    "editor.dragAndDrop"
    "editor.find.addExtraSpaceOnTop"
    "editor.find.seedSearchStringFromSelection"
    "editor.fontFamily"
    "editor.fontLigatures"
    "editor.fontSize"
    "editor.fontWeight"
    "editor.formatOnSave"
    "editor.insertSpaces"
    "editor.minimap.autohide"
    "editor.minimap.renderCharacters"
    "editor.minimap.showSlider"
    "editor.padding.top"
    "editor.padding.bottom"
    "editor.smoothScrolling"
    "editor.tabSize"
    "editor.inlayHints.enabled"

    # window settings
    "window.autoDetectColorScheme"
    "window.confirmBeforeClose"
    "window.dialogStyle"
    "window.restoreFullscreen"
    "window.titleBarStyle"
    "window.zoomLevel"
    "window.commandCenter"
    "window.menuBarVisibility"
    "window.enableMenuBarMnemonics"
    "window.customMenuBarAltFocus"

    # workbench settings
    "workbench.activityBar.location"
    "workbench.commandPalette.preserveInput"
    "workbench.editor.limit.enabled"
    "workbench.editor.limit.excludeDirty"
    "workbench.editor.limit.value"
    "workbench.panel.defaultLocation"
    "workbench.panel.opensMaximized"
    "workbench.reduceMotion"
    "workbench.startupEditor"
    "workbench.tips.enabled"
    "workbench.iconTheme"
    "workbench.layoutControl.enabled"
    "workbench.settings.applyToAllProfiles"
    "workbench.colorTheme"
    "workbench.preferredDarkColorTheme"
    "workbench.preferredLightColorTheme"

    # one dark pro theme settings
    "oneDarkPro.markdownStyle"
    "oneDarkPro.vivid"

    # files settings
    "files.simpleDialog.enable"
    "files.trimFinalNewlines"
    "files.trimTrailingWhitespace"
    "files.autoSave"

    # terminal settings
    "terminal.integrated.cursorBlinking"
    "terminal.integrated.cursorStyle"
    "terminal.integrated.cursorStyleInactive"
    "terminal.integrated.cursorWidth"
    "terminal.integrated.defaultProfile.windows"
    "terminal.integrated.defaultProfile.linux"
    "terminal.integrated.defaultProfile.osx"
    "terminal.integrated.fontFamily"
    "terminal.integrated.fontSize"
    "terminal.integrated.hideOnStartup"
    "terminal.integrated.tabs.enabled"
    "terminal.integrated.profiles.linux"
    "terminal.integrated.profiles.osx"
    "terminal.integrated.profiles.windows"

    # diff settings
    "diffEditor.renderSideBySide"

    # output settings
    "output.smartScroll.enabled"

    # debug settings
    "debug.console.fontFamily"
    "debug.console.fontSize"
    "debug.toolBarLocation"

    # extensions settings
    "extensions.autoCheckUpdates"
    "extensions.autoUpdate"
    "extensions.ignoreRecommendations"

    # problems settings
    "problems.defaultViewMode"

    # search settings
    "search.mode"

    # editor settings
    "breadcrumbs.enabled"

    # zen mode settings
    "zenMode.centerLayout"
    "zenMode.fullScreen"
    "zenMode.hideLineNumbers"

    # accessibility settings
    "accessibility.dimUnfocused.enabled"
    "accessibility.dimUnfocused.opacity"

    # security settings
    "security.workspace.trust.banner"
    "security.workspace.trust.startupPrompt"

    # scm settings
    "scm.repositories.sortOrder"

    # json settings
    "json.format.keepLines"

    # vim settings
    "vim.vimrc.enable"
    "vim.vimrc.path"

    # devcontainer settings
    "dev.containers.dockerPath"
    "dev.containers.mountWaylandSocket"

    "markdown-mermaid.darkModeTheme"
    "python.terminal.activateEnvironment"
  ];

  github.copilot.nextEditSuggestions.enabled = true;
  workbench.iconTheme = "vira-icons-carbon";
  workbench.colorCustomizations = {
    "[Vira*]" = {
      statusBar.debuggingBackground = "#80CBC433";
      statusBar.debuggingForeground = "#80CBC4";
      toolbar.activeBackground = "#80CBC426";
      button.background = "#80CBC4";
      button.hoverBackground = "#80CBC4cc";
      extensionButton.separator = "#80CBC433";
      extensionButton.background = "#80CBC414";
      extensionButton.border = "#80CBC414";
      extensionButton.foreground = "#80CBC4";
      extensionButton.hoverBackground = "#80CBC433";
      extensionButton.prominentForeground = "#80CBC4";
      extensionButton.prominentBackground = "#80CBC414";
      extensionButton.prominentHoverBackground = "#80CBC433";
      activityBarBadge.background = "#80CBC4";
      activityBar.activeBorder = "#80CBC4";
      activityBarTop.activeBorder = "#80CBC4";
      list.inactiveSelectionIconForeground = "#80CBC4";
      list.activeSelectionForeground = "#80CBC4";
      list.inactiveSelectionForeground = "#80CBC4";
      list.highlightForeground = "#80CBC4";
      sash.hoverBorder = "#80CBC480";
      list.activeSelectionIconForeground = "#80CBC4";
      scrollbarSlider.activeBackground = "#80CBC480";
      editorSuggestWidget.highlightForeground = "#80CBC4";
      textLink.foreground = "#80CBC4";
      progressBar.background = "#80CBC4";
      pickerGroup.foreground = "#80CBC4";
      tab.activeBorder = "#80CBC4";
      tab.activeBorderTop = "#80CBC400";
      tab.unfocusedActiveBorder = "#80CBC4";
      tab.unfocusedActiveBorderTop = "#80CBC400";
      tab.activeModifiedBorder = "#80CBC400";
      notificationLink.foreground = "#80CBC4";
      editorWidget.resizeBorder = "#80CBC4";
      editorWidget.border = "#80CBC4";
      settings.modifiedItemIndicator = "#80CBC4";
      panelTitle.activeBorder = "#80CBC4";
      breadcrumb.activeSelectionForeground = "#80CBC4";
      menu.selectionForeground = "#80CBC4";
      menubar.selectionForeground = "#80CBC4";
      editor.findMatchBorder = "#80CBC4";
      selection.background = "#80CBC440";
      statusBarItem.remoteBackground = "#80CBC414";
      statusBarItem.remoteHoverBackground = "#80CBC4";
      statusBarItem.remoteForeground = "#80CBC4";
      notebook.inactiveFocusedCellBorder = "#80CBC480";
      chat.slashCommandForeground = "#80CBC4";
      chat.avatarForeground = "#80CBC4";
      activityBarBadge.foreground = "#000000";
      button.foreground = "#000000";
      statusBarItem.remoteHoverForeground = "#000000";
    };
  };
  editor.tokenColorCustomizations = {};
}
