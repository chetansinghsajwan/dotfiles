{ localLib, ... }: {
  imports = [
    ./vscode
    ./zed
    ./docker
    ./nixpkgs
    ./clipboard
    ./pv
    ./op
  ]
  ++ (localLib.importDir ./.);
}
