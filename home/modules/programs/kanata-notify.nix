{
  pkgs,
  config,
  localLib,
  ...
}:
let
  # Must match services.kanata.keyboards.main.port in hosts/kanata/default.nix.
  port = 6666;

  watcher = pkgs.writeShellScript "kanata-layer-notify" ''
    set -uo pipefail

    while true; do
      if exec 3<>"/dev/tcp/127.0.0.1/${toString port}"; then
        while IFS= read -r -u3 line; do
          layer=$(${pkgs.jq}/bin/jq -r '.LayerChange.new? // empty' <<<"$line")
          if [ -n "$layer" ]; then
            ${pkgs.libnotify}/bin/notify-send \
              -a kanata \
              -h string:x-canonical-private-synchronous:kanata-layer \
              -t 1500 \
              "Kanata" "Layer: $layer"
          fi
        done
        exec 3<&- 3>&-
      fi
      sleep 2
    done
  '';
in
localLib.mkToggleModule config "kanata-notify" {
  home.packages = with pkgs; [
    jq
    libnotify
  ];

  systemd.user.services.kanata-notify = {
    Unit = {
      Description = "Notify on kanata layer changes";
      After = [ "graphical-session.target" ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${watcher}";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
