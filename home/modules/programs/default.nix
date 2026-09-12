{ localLib, ... }: {
  imports = [
    ./vscode
    ./zed
    ./git
    ./fzf
  ]
  ++ (localLib.importDir ./.);
}
