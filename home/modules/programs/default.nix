{ localLib, ... }: {
  imports = [
    ./vscode
    ./zed
    ./git
    ./fzf
    ./docker
    ./nixpkgs
    ./clipboard
    ./pv
  ]
  ++ (localLib.importDir ./.);
}
