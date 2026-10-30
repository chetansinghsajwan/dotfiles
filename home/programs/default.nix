{ llib, ... }: {
    imports = [
        ./vscode
        ./zed
        ./git
        ./pickers
        ./docker
        ./nixpkgs
        ./clipboard
        ./files
        ./ui
        ./op
    ]
    ++ (llib.importDir ./.);
}
