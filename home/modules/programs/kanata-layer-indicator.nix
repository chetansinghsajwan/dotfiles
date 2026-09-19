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

  # Path of the symlink kanata's systemd service (the NixOS services.kanata
  # module) creates via --symlink-path, pointing at its virtual output
  # uinput device. RUNTIME_DIRECTORY there is "kanata-${keyboard name}" and
  # the symlink itself is named after the keyboard, so for
  # services.kanata.keyboards.main this is always /run/kanata-main/main
  # regardless of which /dev/input/eventN the kernel assigns.
  kanataDevice = "/run/kanata-main/main";

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

  # Reads modifier press/release directly off kanata's virtual output
  # device (not the TCP server, which only reports LayerChange): the
  # tap-hold mod keys in kanata.kbd emit real lctrl/lshift/.../rctrl key
  # events, so this is the same signal the compositor itself acts on.
  # Requires the user to be in the "kanata-watch" group set up in
  # hosts/nixos/system.nix (read access to that one device, not all input).
  pythonWithEvdev = pkgs.python3.withPackages (ps: [ ps.evdev ]);

  modsWatcherPy = pkgs.writeText "kanata-mods-indicator-watch.py" ''
    import sys
    from evdev import InputDevice, ecodes

    MODS = {
        ecodes.KEY_LEFTCTRL: "ctrl",
        ecodes.KEY_RIGHTCTRL: "ctrl",
        ecodes.KEY_LEFTSHIFT: "shift",
        ecodes.KEY_RIGHTSHIFT: "shift",
        ecodes.KEY_LEFTALT: "alt",
        ecodes.KEY_RIGHTALT: "alt",
        ecodes.KEY_LEFTMETA: "meta",
        ecodes.KEY_RIGHTMETA: "meta",
    }

    dev = InputDevice(sys.argv[1])
    # Counted, not boolean, so e.g. both a (lctrl) and ; (rctrl) held at
    # once don't cancel out when one of the two is released.
    held = {name: 0 for name in set(MODS.values())}

    for event in dev.read_loop():
        if event.type != ecodes.EV_KEY or event.code not in MODS:
            continue

        name = MODS[event.code]
        if event.value == 1:
            held[name] += 1
        elif event.value == 0:
            held[name] = max(0, held[name] - 1)
        else:
            continue  # autorepeat

        print(",".join(sorted(n for n, count in held.items() if count > 0)), flush=True)
  '';

  modsWatcher = pkgs.writeShellScript "kanata-mods-indicator-watch" ''
    set -uo pipefail

    while true; do
      if [ -e "${kanataDevice}" ]; then
        ${pythonWithEvdev}/bin/python3 ${modsWatcherPy} "${kanataDevice}" || true
      fi
      sleep 1
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
        // Comma-separated subset of "ctrl,shift,alt,meta" currently held.
        property string heldMods: ""

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

        Process {
            running: true
            command: ["${modsWatcher}"]
            stdout: SplitParser {
                onRead: line => {
                    heldMods = line;
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

            // Fixed size (not derived from content) so the pill doesn't
            // resize as the layer name or held mods change. Wide enough to
            // fit "fallback", the longest layer name.
            implicitWidth: 140
            implicitHeight: 58

            Rectangle {
                anchors.fill: parent
                radius: 16
                color: "#f01e1e2e"
                border.color: "#8089b4fa"
                border.width: 2

                Column {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        id: label
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: kanataLayer
                        color: kanataLayer === "main" ? "#cdd6f4" : "#89b4fa"
                        font.family: "monospace"
                        font.pixelSize: 20
                        font.bold: true
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6

                        Text {
                            text: "C"
                            font.family: "monospace"
                            font.pixelSize: 13
                            font.bold: true
                            color: heldMods.includes("ctrl") ? "#f38ba8" : "#585b70"
                        }
                        Text {
                            text: "S"
                            font.family: "monospace"
                            font.pixelSize: 13
                            font.bold: true
                            color: heldMods.includes("shift") ? "#f9e2af" : "#585b70"
                        }
                        Text {
                            text: "A"
                            font.family: "monospace"
                            font.pixelSize: 13
                            font.bold: true
                            color: heldMods.includes("alt") ? "#a6e3a1" : "#585b70"
                        }
                        Text {
                            text: "M"
                            font.family: "monospace"
                            font.pixelSize: 13
                            font.bold: true
                            color: heldMods.includes("meta") ? "#89b4fa" : "#585b70"
                        }
                    }
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
