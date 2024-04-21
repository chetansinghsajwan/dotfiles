{ config, pkgs, ... }:
{
    home.packages = [
        pkgs.obsidian
    ];

    nixpkgs.config.permittedInsecurePackages = [
        "electron-25.9.0"
    ];
}
