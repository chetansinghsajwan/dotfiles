{ pkgs, ... }:
{
  home.packages = with pkgs; [
    cmake
    ninja
  ];

  programs.vscode =
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
        cmake = {
          cmakePath = "${pkgs.cmake}/bin/cmake";
          sourceDirectory = "\${workspaceFolder}";
          buildDirectory = buildDir;
          installPrefix = installDir;
          autoSelectActiveFolder = true;
          loadCompileCommands = true;
          # copyCompileCommands = "${buildDir}/compile_commands.json";
          configureOnEdit = false;
          configureOnOpen = false;
          saveBeforeBuild = true;
          buildBeforeRun = true;
          revealLog = "focus";
          preferredGenerators = [ "Ninja" "Unix MakeFiles" ];
        };

        launch = {
          configurations = [
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
}
