{ vscode-extensions, ... }:
{
  programs.vscode = {
    extensions = with vscode-extensions.vscode-marketplace; [
      github.github-vscode-theme
    ];
  };
}
