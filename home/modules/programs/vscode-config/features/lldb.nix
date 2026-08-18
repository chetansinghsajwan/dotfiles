{ pkgs, vscode-extensions, ... }:
{
  home.packages = with pkgs; [
    lldb_18
  ];

  programs.vscode = {
    extensions = with vscode-extensions.vscode-marketplace; [
      vadimcn.vscode-lldb
    ];

    userSettings.launch = {
      configurations = [
        {
          name = "lldb debug";
          type = "lldb";
          request = "launch";
          program = "\${input:lldbTarget}";
        }
      ];

      inputs = [
        {
          id = "lldbTarget";
          description = "Enter the path to the target to debug";
          type = "promptString";
        }
      ];
    };
  };
}
