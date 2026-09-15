{ localLib, ... }: {
  imports = [
    ./vscode
    ./zed
    ./git
    ./fzf
    ./docker
    ./nixpkgs
  ]
  ++ (localLib.importDir ./.);
}
