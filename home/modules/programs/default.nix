{ localLib, ... }: {
  imports = [
    ./vscode
    ./clipboard
  ]
  ++ (localLib.importDir ./.);
}
