{ config, pkgs, ... }:
{
    home.packages = [
        pkgs.vlc
    ];

    home.file."${config.home.homeDirectory}/.config/vlc/vlcrc".source = ../../../vlc/vlcrc;
}
