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
        ./pick
        ./ui
        ./op
    ]
    ++ (llib.importDir ./.);
}
