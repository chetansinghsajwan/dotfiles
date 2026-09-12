{ localLib, ... }: {
  imports = [
    ./vscode
    ./zed
    ./git
  ]
  ++ (localLib.importDir ./.);
}
