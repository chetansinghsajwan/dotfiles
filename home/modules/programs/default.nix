{ localLib, ... }: {
  imports = [
    ./zed
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
