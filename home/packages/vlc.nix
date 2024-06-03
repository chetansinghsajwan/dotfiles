{ config, pkgs, ... }:
let
    vlcrcFile = "${config.home.homeDirectory}/.config/vlc/vlcrc";
in
{
    home.packages = with pkgs; [
        vlc
    ];

    home.file.${vlcrcFile}.text = ''
        qt-system-tray=0
        qt-video-autoresize=0
        qt-privacy-ask=0
        freetype-font=Noto Sans
        aout=any
        audio-filter=normvol
        snapshot-path=images/vlc/screenshots
        vout=any
        audio-language=eng
        sub-language=eng
        vod-server=any
        metadata-network-access=1
        short-jump-size=5
        medium-jump-size=10
        long-jump-size=60
    '';
}
