{ vscode-extensions, ... }:
{
  programs.vscode = {
    extensions = with vscode-extensions.vscode-marketplace; [
      zhuangtongfa.material-theme
    ];

    userSettings = {
      workbench.colorTheme = "One Dark Pro Darker";
    };
  };
}
