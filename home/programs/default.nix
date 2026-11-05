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
        ./fonts
        ./op
    ]
    ++ (llib.importDir ./.);
}
