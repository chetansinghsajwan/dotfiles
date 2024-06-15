{ pkgs, ... }:
{
  home.packages = with pkgs; [
    cmake
    ninja
  ];

  programs.vscode = {
    extensions = with pkgs.vscode-extensions; [
      twxs.cmake
      ms-vscode.cmake-tools
    ];

    userSettings.cmake = {
      cmakePath = "${pkgs.cmake}/bin/cmake";
      sourceDirectory = "\${workspaceFolder}";
      buildDirectory = "\${workspaceFolder}/build";
      installPrefix = "\${workspaceFolder}/install";
      copyCompileCommands = "\${workspaceFolder}/build/compile_commands.json";
      autoSelectActiveFolder = true;
      loadCompileCommands = true;
      configureOnEdit = false;
      configureOnOpen = false;
      saveBeforeBuild = true;
      buildBeforeRun = true;
      revealLog = "focus";
      skipConfigureIfCachePresent = true;
      preferredGenerators = [ "Ninja" "Unix MakeFiles" ];
    };
  };
}
