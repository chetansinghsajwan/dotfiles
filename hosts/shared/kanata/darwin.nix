{ pkgs, ... }:
let
    driver = pkgs.karabiner-dk;
    parentAppDir = "/Applications/.Nix-Karabiner";
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

    system.activationScripts.postActivation.text = ''
        ${parentAppDir}/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager activate || true
    '';

    launchd.daemons.karabiner-vhidd.serviceConfig = {
        Label = "org.nixos.karabiner-vhidd";
        ProgramArguments = [ daemonBin ];
        RunAtLoad = true;
        KeepAlive = true;
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
