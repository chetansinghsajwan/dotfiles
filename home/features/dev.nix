{
    config,
    pkgs,
    lib,
    ...
}: let
    enableDev = config.dotfiles.features.dev;
    enableGui = config.dotfiles.features.gui;
in {
    config = lib.mkIf enableDev {
        home.packages = with pkgs; [
            # cmake
            # lldb
            # clang
            # llvmPackages_18.clang-tools
            nodejs

            # Pushes store paths to the binary cache (chetansinghsajwan-dotfiles.cachix.org).
            cachix
        ];

        programs = {
            vscode.enable = enableGui;
            zed-editor.enable = enableGui;
        };
    };
}
