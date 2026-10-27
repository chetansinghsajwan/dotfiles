_: {
    programs.vscode.profiles.default.keybindings = [
        {
            args = {
                text = "_";
            };
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
        {
            command = "cursorMove";
            args = {
                to = "up";
                by = "line";
                value = 10;
            };
            key = "ctrl+up";
            when = "editorTextFocus";
        }
        {
            command = "cursorMove";
            args = {
                to = "down";
                by = "line";
                value = 10;
            };
            key = "ctrl+down";
            when = "editorTextFocus";
        }
        {
            command = "cursorWordEndLeft";
            key = "ctrl+left";
            when = "editorTextFocus";
        }
        {
            command = "cursorWordEndRight";
            key = "ctrl+right";
            when = "editorTextFocus";
        }
        {
            command = "cursorMove";
            args = {
                to = "up";
                by = "line";
                value = 10;
                select = true;
            };
            key = "ctrl+shift+up";
            when = "editorTextFocus";
        }
        {
            command = "cursorMove";
            args = {
                to = "down";
                by = "line";
                value = 10;
                select = true;
            };
            key = "ctrl+shift+down";
            when = "editorTextFocus";
        }
        {
            command = "cursorWordEndLeftSelect";
            key = "ctrl+shift+left";
            when = "editorTextFocus";
        }
        {
            command = "cursorWordEndRightSelect";
            key = "ctrl+shift+right";
            when = "editorTextFocus";
        }
        {
            command = "deleteWordLeft";
            key = "ctrl+backspace";
            when = "editorTextFocus && !editorReadonly";
        }
        {
            command = "deleteWordRight";
            key = "ctrl+delete";
            when = "editorTextFocus && !editorReadonly";
        }
    ];
}
