{ localLib, ... }: {
  imports = [
    ./vscode
    ./zed
    ./git
    ./fzf
    ./docker
  ]
  ++ (localLib.importDir ./.);
}
