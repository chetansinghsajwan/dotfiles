{ pkgs, ... }:
{
  gtk = {
    enable = true;
  };

  home.packages = with pkgs; [
    gnomeExtensions.gsconnect
    gnomeExtensions.blur-my-shell
    gnomeExtensions.user-themes
    gnomeExtensions.tray-icons-reloaded
    gnomeExtensions.vitals
    gnomeExtensions.sound-output-device-chooser
    gnomeExtensions.space-bar

    # for gsconnect
    openssl
  ];

  dconf.settings = {
    "org/gnome/shell" = {
      favorite-apps = [];
      disable-user-extensions = false;
      enabled-extensions = [
        "gsconnect@andyholmes.github.io"
        "blur-my-shell@aunetx"
        "user-theme@gnome-shell-extensions.gcampax.github.com"
        "trayIconsReloaded@selfmade.pl"
        "Vitals@CoreCoding.com"
        "sound-output-device-chooser@kgshank.net"
        "space-bar@luchrioh"
      ];
    };

    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      enable-hot-corners = false;
    };

    "org/gnome/desktop/background" = {
      # picture-uri = "file://../../wallpapers/gnome-default-light.png";
      # picture-uri-dark = "file://../../wallpapers/gnome-default-dark.png";
    };
  };
}
