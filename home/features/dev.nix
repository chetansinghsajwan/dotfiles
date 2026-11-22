{
    config,
    pkgs,
    lib,
    ...
}: let
    enableDev = config.dotfiles.features.dev;
    enableGui = config.dotfiles.features.gui;
    enableEditors = config.dotfiles.features.editors;
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
            # Off by default: set `dotfiles.features.editors` to bring them back.
            vscode.enable = enableGui && enableEditors;
            zed-editor.enable = enableGui && enableEditors;
        };
    };
}
