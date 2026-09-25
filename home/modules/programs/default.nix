{ localLib, ... }: {
  imports = [
    ./vscode
    ./zed
    ./clipboard
  ]
  ++ (localLib.importDir ./.);
}
