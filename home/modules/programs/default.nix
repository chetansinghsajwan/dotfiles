{ localLib, ... }: {
  imports = [
    ./vscode
    ./zed
    ./git
    ./fzf
    ./docker
    ./nixpkgs
    ./clipboard
  ]
  ++ (localLib.importDir ./.);
}
