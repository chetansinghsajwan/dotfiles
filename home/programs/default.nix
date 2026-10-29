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
        ./files
        ./pick
        ./git-panel
        ./ui
        ./op
    ]
    ++ (llib.importDir ./.);
}
