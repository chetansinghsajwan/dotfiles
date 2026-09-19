{
  pkgs,
  config,
  localLib,
  caelestia-shell,
  ...
}:
let
  # Must match services.kanata.keyboards.main.port in hosts/kanata/default.nix.
  port = 6666;

  # Build the exact same quickshell derivation caelestia-shell already builds
  # for itself (nix/default.nix: `quickshell.withModules [qt6.qtimageformats
  # m3shapes]`), so this reuses that cached build instead of compiling a
  # second, differently-configured quickshell from source.
  system = pkgs.stdenv.hostPlatform.system;
  m3shapes = caelestia-shell.inputs.m3shapes.packages.${system}.default;
  quickshell =
    (caelestia-shell.inputs.quickshell.packages.${system}.default.override {
      withX11 = false;
      withI3 = false;
    }).withModules
      [
        pkgs.qt6.qtimageformats
        m3shapes
      ];

  watcher = pkgs.writeShellScript "kanata-layer-indicator-watch" ''
    set -uo pipefail

    while true; do
      if exec 3<>"/dev/tcp/127.0.0.1/${toString port}"; then
        while IFS= read -r -u3 line; do
          layer=$(${pkgs.jq}/bin/jq -r '.LayerChange.new? // empty' <<<"$line")
          if [ -n "$layer" ]; then
            echo "$layer"
          fi
        done
        exec 3<&- 3>&-
      fi
      sleep 2
    done
  '';

  shell = pkgs.writeText "kanata-layer-indicator-shell.qml" ''
    import QtQuick
    import Quickshell
    import Quickshell.Wayland
    import Quickshell.Io

    ShellRoot {
        // Named kanataLayer, not layer: every Item has a built-in `layer`
        // grouped property (render-layer effects), which would shadow a
        // plain `property string layer` for any binding that looks it up
        // through the scope chain (e.g. Text.text below).
        property string kanataLayer: "main"

        Process {
            running: true
            command: ["${watcher}"]
            stdout: SplitParser {
                onRead: line => {
                    if (line.length > 0)
                        kanataLayer = line;
                }
            }
        }

        PanelWindow {
            WlrLayershell.namespace: "kanata-layer-indicator"
            WlrLayershell.layer: WlrLayer.Overlay

            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                right: true
            }
            margins {
                top: 8
                right: 8
            }

            // Fixed size (not derived from label.implicitWidth) so the pill
            // doesn't resize as the layer name changes.
            implicitWidth: 90
            implicitHeight: 40

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: "#f01e1e2e"
                border.color: "#8089b4fa"
                border.width: 2

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: kanataLayer
                    color: kanataLayer === "main" ? "#cdd6f4" : "#89b4fa"
                    font.family: "monospace"
                    font.pixelSize: 22
                    font.bold: true
                }
            }
        }
    }
  '';
in
localLib.mkToggleModule config "kanata-layer-indicator" {
  systemd.user.services.kanata-layer-indicator = {
    Unit = {
      Description = "Persistent indicator of the active kanata layer";
      After = [ "graphical-session.target" ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${quickshell}/bin/quickshell -n -p ${shell}";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
