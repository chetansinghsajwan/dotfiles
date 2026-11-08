{ pkgs, ... }:
let
    driver = pkgs.karabiner-dk;
    parentAppDir = "/Applications/.Nix-Karabiner";
    manager = "${parentAppDir}/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager";
    daemonBin = "${driver}/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon";
in
{
    environment.systemPackages = [ pkgs.kanata ];

    # The DriverKit extension must live in /Applications, not a symlink.
    system.activationScripts.preActivation.text = ''
        rm -rf ${parentAppDir}
        mkdir -p ${parentAppDir}
        cp -r ${driver}/Applications/.Karabiner-VirtualHIDDevice-Manager.app ${parentAppDir}
    '';

    # `activate` blocks until the system extension is approved in System Settings
    # (Privacy & Security), so it runs here, never in an activation script, where it
    # would hang the rebuild with no prompt in sight.
    launchd.daemons.karabiner-vhidd = {
        script = ''
            '${manager}' activate
            exec '${daemonBin}'
        '';
        serviceConfig = {
            Label = "org.nixos.karabiner-vhidd";
            RunAtLoad = true;
            KeepAlive = true;
            StandardErrorPath = "/var/log/karabiner-vhidd.log";
        };
    };

    launchd.daemons.kanata.serviceConfig = {
        Label = "org.nixos.kanata";
        ProgramArguments = [
            "${pkgs.kanata}/bin/kanata"
            "--cfg"
            "${./kanata.kbd}"
            "--port"
            "6666"
        ];
        RunAtLoad = true;
        KeepAlive = true;
        StandardErrorPath = "/var/log/kanata.log";
    };
}
