{ localLib, ... }: {
  imports = [
    ./clipboard
  ]
  ++ (localLib.importDir ./.);
}
