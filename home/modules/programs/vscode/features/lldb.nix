{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.programs.vscode.enable {
    home.packages = with pkgs; [
      lldb_19
    ];

    programs.vscode = {
      extensions = with pkgs.vscode-extensions; [
        llvm-vs-code-extensions.lldb-dap
      ];

      userSettings = {
        launch = {
          configurations = [
            {
              name = "lldb debug";
              type = "lldb";
              request = "launch";
              program = "\${input:lldbTarget}";
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
    };
  };
}
