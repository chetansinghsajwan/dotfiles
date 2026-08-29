{ vscode-extensions, ... }:
{
  programs.vscode = {
    extensions = with vscode-extensions.vscode-marketplace; [
      pkief.material-icon-theme
    ];

    userSettings = {
      workbench.iconTheme = "material-icon-theme";
    };
  };
}
