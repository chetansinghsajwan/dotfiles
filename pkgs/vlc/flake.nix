{
  description = "vlc: media player";

  # No nix-wrapper-modules here: vlc has no CLI flags worth baking in, and
  # its config lives in a fixed-path ini file (~/.config/vlc/vlcrc), so
  # this just installs the package and writes that file directly.
  outputs = _: {
    homeModules.default =
      {
        config,
        pkgs,
        lib,
        localLib,
        ...
      }:
      let
        # snapshot-path must be an absolute path - VLC silently ignores
        # a relative one (it doesn't error, it just falls back to its
        # own default save location), which is what the previous
        # "images/vlc/screenshots" value did.
        snapshotDir =
          if config.dotfiles.system.isDarwin then
            "${config.home.homeDirectory}/Pictures/vlc-screenshots"
          else
            "${config.home.homeDirectory}/pictures/vlc-screenshots";
      in
      localLib.mkToggleModule config "vlc" {
        home.packages = [ pkgs.vlc ];

        home.file.".config/vlc/vlcrc".text = ''
          qt-system-tray=0
          qt-video-autoresize=0
          qt-privacy-ask=0
          aout=any
          audio-filter=normvol
          snapshot-path=${snapshotDir}
          vout=any
          audio-language=eng
          sub-language=eng
          vod-server=any
          metadata-network-access=1
          short-jump-size=5
          medium-jump-size=10
          long-jump-size=60
        '';

        # VLC doesn't create the snapshot directory itself - without
        # this, snapshot saves fail until the user creates it by hand.
        home.activation.createVlcSnapshotDir = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run mkdir -p ${lib.escapeShellArg snapshotDir}
        '';
      };
  };
}
