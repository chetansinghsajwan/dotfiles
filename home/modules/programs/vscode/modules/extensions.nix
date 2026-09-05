{ pkgs, ... }: {
  programs.vscode ={
    extensions= with pkgs.vscode-extensions; [
      mhutchie.git-graph # Git graph
      ms-azuretools.vscode-containers # Container Tools by Microsoft
      ms-vscode-remote.remote-containers # Dev containers by Microsoft
      ms-azuretools.vscode-docker # Docker by Microsoft
      # task.vscode-task # Taskfile
      # jetpack-io.devbox # Devbox by jetify
    ];
  };
}
