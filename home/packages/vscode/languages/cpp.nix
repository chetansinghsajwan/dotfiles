{ ... }:
{
  programs.vscode = {
    userSettings = {
      files.associations = {
        "*.cppm" = "cpp";
        "*.cppi" = "cpp";
      };
    };
  };
}
