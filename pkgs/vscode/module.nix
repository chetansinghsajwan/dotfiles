# This repo's own VS Code customization, consolidated from the previous
# modules/settings.nix, modules/extensions.nix, modules/keybindings.nix,
# languages/{nix,cpp,json}.nix, features/{lldb,clangd,cmake}.nix, and
# themes/material-icons.nix.
#
# terminal.integrated.defaultProfile.{windows,linux,osx} are set separately
# by whatever imports this (see flake.nix's `homeModules.default`), since
# they need the outer config's dotfiles.shell.program - a plain wrapper
# module like this one only ever sees its own submodule config, not the
# config around it. They're still present here (as an empty-string
# placeholder) purely so `flattenAttrs` below produces the same key list
# `workbench.settings.applyToAllProfiles` had before: flattening only
# needs each leaf's *path*, never its value.
{ pkgs, ... }:
let
  # Ported from modules/settings.nix: flattens nested attrs into
  # dot-notation keys, e.g. { a.b.c = 1; d = 2; } -> [ "a.b.c" "d" ].
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

  # This was the sole content of modules/settings.nix's own `userSettings`
  # - the base set that gets flattened into applyToAllProfiles, separate
  # from the language/feature-specific settings merged in below.
  baseSettings = {
    "editor.guides.highlightActiveIndentation" = true;
    "editor.codeLens" = true;
    "editor.guides.bracketPairsHorizontal" = true;
    "editor.bracketPairColorization.enabled" = true;
    "editor.cursorBlinking" = "phase";
    "editor.cursorSmoothCaretAnimation" = "on";
    "editor.cursorStyle" = "line";
    "editor.find.seedSearchStringFromSelection" = "selection";
    "editor.fontLigatures" = true;
    "editor.minimap.renderCharacters" = false;
    "editor.minimap.showSlider" = "always";
    "editor.padding.top" = 10;
    "editor.padding.bottom" = 10;
    "editor.smoothScrolling" = true;
    "editor.inlayHints.enabled" = "offUnlessPressed";

    "window.commandCenter" = false;
    "window.dialogStyle" = "custom";
    "window.titleBarStyle" = "native";
    "window.menuBarVisibility" = "toggle";

    "workbench.editor.limit.enabled" = true;
    "workbench.editor.limit.excludeDirty" = true;
    "workbench.editor.limit.value" = 8;
    "workbench.startupEditor" = "none";
    "workbench.tips.enabled" = false;
    "workbench.layoutControl.enabled" = false;

    "files.autoSave" = "afterDelay";
    "files.autoSaveDelay" = 1000;
    "files.trimFinalNewlines" = true;
    "files.trimTrailingWhitespace" = true;

    "terminal.integrated.cursorStyle" = "line";
    # Placeholder - see module docstring. The real value is merged in from
    # outside.
    "terminal.integrated.defaultProfile.windows" = "";
    "terminal.integrated.defaultProfile.linux" = "";
    "terminal.integrated.defaultProfile.osx" = "";
    "terminal.integrated.tabs.enabled" = true;
    "terminal.integrated.profiles.windows" = {
      "git-bash".source = "PowerShell";
      "ubuntu-wsl" = {
        path = "C:\\WINDOWS\\System32\\wsl.exe";
        args = [
          "-d"
          "Ubuntu"
        ];
      };
    };

    "zenMode.centerLayout" = false;
    "zenMode.fullScreen" = true;
    "zenMode.hideLineNumbers" = false;

    "github.copilot.nextEditSuggestions.enabled" = true;

    "diffEditor.renderSideBySide" = true;

    "output.smartScroll.enabled" = true;
    "extensions.ignoreRecommendations" = true;
    "problems.defaultViewMode" = "table";
    "breadcrumbs.enabled" = true;
    "security.workspace.trust.banner" = "never";
    "security.workspace.trust.startupPrompt" = "never";
    "scm.repositories.sortOrder" = "path";
    "settingsSync.keybindingsPerPlatform" = false;
  };

  clangTools = pkgs.llvmPackages_19.clang-tools;
  cmakeBuildDir = "\${workspaceFolder}/build";
  cmakeInstallDir = "\${workspaceFolder}/install";
in
{
  config = {
    runtimePkgs =
      with pkgs;
      [
        nil
        nixpkgs-fmt
        lldb_19
        cmake
        ninja
      ]
      ++ [ clangTools ];

    extensions = with pkgs.vscode-extensions; [
      # modules/extensions.nix
      mhutchie.git-graph
      ms-azuretools.vscode-containers
      ms-vscode-remote.remote-containers
      ms-azuretools.vscode-docker
      # languages/nix.nix
      jnoortheen.nix-ide
      # features/lldb.nix
      llvm-vs-code-extensions.lldb-dap
      # features/clangd.nix
      llvm-vs-code-extensions.vscode-clangd
      # features/cmake.nix
      twxs.cmake
      ms-vscode.cmake-tools
      # themes/material-icons.nix
      pkief.material-icon-theme
    ];

    keybindings = [
      {
        args.text = "_";
        command = "type";
        key = "shift+space";
      }
      {
        command = "explorer.newFile";
        key = "ctrl+n";
      }
      {
        command = "-workbench.action.files.newUntitledFile";
        key = "ctrl+n";
      }
      {
        command = "workbench.action.showCommands";
        key = "ctrl+p";
      }
      {
        command = "workbench.action.quickOpenNavigateNextInFilePicker";
        key = "ctrl+p";
        when = "inQuickOpen";
      }
      {
        command = "workbench.action.quickOpenNavigatePreviousInFilePicker";
        key = "ctrl+shift+p";
        when = "inQuickOpen";
      }
      {
        command = "editor.action.formatDocument";
        key = "ctrl+shift+i";
        when = "editorHasDocumentFormattingProvider && editorTextFocus && !editorReadonly && !inCompositeEditor";
      }
      {
        command = "-editor.action.formatDocument";
        key = "shift+alt+f";
      }
      {
        command = "-workbench.action.showCommands";
        key = "ctrl+shift+p";
      }
      {
        command = "workbench.action.terminal.focusNext";
        key = "ctrl+tab";
        when = "terminalFocus && terminalHasBeenCreated && !terminalEditorFocus || terminalFocus && terminalProcessSupported && !terminalEditorFocus";
      }
      {
        command = "-notebook.cell.executeAndFocusContainer";
        key = "ctrl+enter";
        when = "notebookCellListFocused || editorTextFocus && inputFocus && notebookEditorFocused";
      }
      {
        command = "-jupyter.runByLineStop";
        key = "ctrl+enter";
        when = "notebookCellResource in 'jupyter.notebookeditor.runByLineCells'";
      }
      {
        command = "-jupyter.runcurrentcell";
        key = "ctrl+enter";
        when = "editorTextFocus && isWorkspaceTrusted && jupyter.hascodecells && !editorHasSelection && !isCompositeNotebook && !notebookEditorFocused";
      }
      {
        command = "-jupyter.runcurrentcelladvance";
        key = "shift+enter";
        when = "editorTextFocus && isWorkspaceTrusted && jupyter.hascodecells && !editorHasSelection && !isCompositeNotebook && !notebookEditorFocused";
      }
      {
        command = "-jupyter.execSelectionInteractive";
        key = "shift+enter";
        when = "editorTextFocus && isWorkspaceTrusted && jupyter.ownsSelection && !findInputFocussed && !isCompositeNotebook && !notebookEditorFocused && !replaceInputFocussed && editorLangId == 'python'";
      }
      {
        command = "-notebook.cell.executeAndSelectBelow";
        key = "shift+enter";
        when = "notebookCellListFocused && !interactiveEditorFocused && notebookCellType == 'code' || editorTextFocus && inputFocus && notebookEditorFocused && !interactiveEditorFocused";
      }
      {
        command = "-python.execInREPL";
        key = "shift+enter";
        when = "config.python.REPL.sendToNativeREPL && editorTextFocus && !accessibilityModeEnabled && !isCompositeNotebook && !jupyter.ownsSelection && !notebookEditorFocused && editorLangId == 'python'";
      }
      {
        command = "-python.execSelectionInTerminal";
        key = "shift+enter";
        when = "editorTextFocus && !findInputFocussed && !isCompositeNotebook && !jupyter.ownsSelection && !notebookEditorFocused && !replaceInputFocussed && editorLangId == 'python'";
      }
      {
        command = "-workbench.action.closeWindow";
        key = "ctrl+shift+w";
      }
      {
        command = "-github.copilot.generate";
        key = "ctrl+enter";
        when = "editorTextFocus && github.copilot.activated && !commentEditorFocused";
      }
      {
        command = "workbench.view.explorer";
        key = "ctrl+shift+e";
        when = "viewContainer.workbench.view.explorer.enabled";
      }
      {
        key = "ctrl+e";
        command = "workbench.action.quickOpen";
      }
    ];

    userSettings = baseSettings // {
      "workbench.settings.applyToAllProfiles" = flattenAttrs "" baseSettings;

      # Was profiles.default.{enableUpdateCheck,enableExtensionUpdateCheck} = false
      "update.mode" = "none";
      "extensions.autoCheckUpdates" = false;

      # languages/cpp.nix
      "files.associations" = {
        "*.cppm" = "cpp";
        "*.cppi" = "cpp";
      };

      # languages/json.nix
      "json.format.keepLines" = true;

      # languages/nix.nix
      "nix.formatterPath" = "nixpkgs-fmt";
      "nix.enableLanguageServer" = true;
      "nix.serverPath" = "${pkgs.nil}/bin/nil";
      "nix.serverSettings".nil.formatting.command = [ "nixpkgs-fmt" ];

      # features/clangd.nix
      "clangd.path" = "${clangTools}/bin/clangd";
      "clangd.arguments" = [ "--compile-commands-dir=\${workspaceFolder}/build" ];
      "clangd.checkUpdates" = false;
      "clangd.enableCodeCompletion" = true;
      "clangd.onConfigChanged" = "restart";
      "clangd.restartAfterCrash" = true;

      # features/cmake.nix
      "cmake.cmakePath" = "${pkgs.cmake}/bin/cmake";
      "cmake.sourceDirectory" = "\${workspaceFolder}";
      "cmake.buildDirectory" = cmakeBuildDir;
      "cmake.installPrefix" = cmakeInstallDir;
      "cmake.autoSelectActiveFolder" = true;
      "cmake.loadCompileCommands" = true;
      "cmake.configureOnEdit" = false;
      "cmake.configureOnOpen" = false;
      "cmake.saveBeforeBuild" = true;
      "cmake.buildBeforeRun" = true;
      "cmake.revealLog" = "focus";
      "cmake.preferredGenerators" = [
        "Ninja"
        "Unix MakeFiles"
      ];

      # themes/material-icons.nix
      "workbench.iconTheme" = "material-icon-theme";

      # features/lldb.nix + features/cmake.nix both target `launch` -
      # combined by hand here since freeform JSON options don't
      # concatenate lists the way typed `listOf` options do.
      launch = {
        configurations = [
          {
            name = "lldb debug";
            type = "lldb";
            request = "launch";
            program = "\${input:lldbTarget}";
          }
          {
            name = "cmake debug";
            type = "lldb";
            request = "launch";
            program = "\${command:cmake.launchTargetPath}";
          }
        ];

        input = [
          {
            id = "lldbTarget";
            description = "Enter the path to the target to debug";
            type = "promptString";
          }
        ];
      };
    };

    userTasks.tasks = [
      {
        label = "cmake build all";
        command = "cmake --build ${cmakeBuildDir}";
        problemMatcher = [ ];
      }
      {
        label = "cmake build target";
        command = "cmake --build ${cmakeBuildDir} --target \${input:cmakeTarget}";
        problemMatcher = [ ];
      }
      {
        label = "cmake clean";
        command = "cmake --build build --target clean";
        problemMatcher = [ ];
      }
      {
        label = "cmake run";
        command = "\${command:cmake.launchTargetPath}";
        type = "process";
        problemMatcher = [ ];
      }
      {
        label = "cmake debug";
        command = "\${command:workbench.action.debug.selectandstart}";
        args = [ "cmake debug" ];
        problemMatcher = [ ];
      }
      {
        label = "cmake install";
        command = "cmake --install ${cmakeBuildDir} --install-prefix ${cmakeInstallDir}";
        problemMatcher = [ ];
      }
    ];
  };
}
