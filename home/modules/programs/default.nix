{ localLib, ... }: {
  imports = [
    ./git
    ./fzf
    ./docker
    ./nixpkgs
    ./clipboard
    ./pv
    ./op
  ]
  ++ (localLib.importDir ./.);
}
