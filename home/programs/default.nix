{ llib, ... }: {
    imports = [
        ./vscode
        ./zed
        ./git
        ./pickers
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
