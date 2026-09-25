{ localLib, ... }: {
  imports = [
    ./vscode
    ./zed
    ./git
    ./docker
    ./nixpkgs
    ./clipboard
    ./pv
    ./op
  ]
  ++ (localLib.importDir ./.);
}
