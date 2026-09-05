{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.programs.vscode.enable {
    home.packages = with pkgs; [
      cmake
      ninja
    ];

    programs.vscode.profiles.default =
      let
        buildDir = "\${workspaceFolder}/build";
        installDir = "\${workspaceFolder}/install";
      in
      {
        extensions = with pkgs.vscode-extensions; [
          twxs.cmake
          ms-vscode.cmake-tools
        ];

        userSettings = {
          "cmake.cmakePath" = "${pkgs.cmake}/bin/cmake";
          "cmake.sourceDirectory" = "\${workspaceFolder}";
          "cmake.buildDirectory" = buildDir;
          "cmake.installPrefix" = installDir;
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

          "launch" = {
            "configurations" = [
              {
                name = "cmake debug";
                type = "lldb";
                request = "launch";
                program = "\${command:cmake.launchTargetPath}";
              }
            ];
          };
        };

        userTasks.tasks = [
          {
            label = "cmake build all";
            command = "cmake --build ${buildDir}";
            problemMatcher = [ ];
          }
          {
            label = "cmake build target";
            command = "cmake --build ${buildDir} --target \${input:cmakeTarget}";
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
            args = [
              "cmake debug"
            ];
            problemMatcher = [ ];
          }
          {
            label = "cmake install";
            command = "cmake --install ${buildDir} --install-prefix ${installDir}";
            problemMatcher = [ ];
          }
        ];
      };
  };
}
