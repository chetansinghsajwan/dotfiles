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
        ./ui
        ./op
    ]
    ++ (llib.importDir ./.);
}
