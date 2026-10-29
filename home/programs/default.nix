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
        ./git-panel
        ./ui
        ./op
    ]
    ++ (llib.importDir ./.);
}
