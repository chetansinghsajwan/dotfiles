{ llib, ... }: {
  imports = [
    ./vscode
    ./zed
    ./git
    ./fzf
    ./docker
    ./nixpkgs
    ./clipboard
    ./pv
    ./op
  ]
  ++ (llib.importDir ./.);
}
