{
    config,
    lib,
    pkgs,
    ...
}:
let
    who = import ./users.nix lib config.dotfiles.users;
    driver = pkgs.karabiner-dk;
    parentAppDir = "/Applications/.Nix-Karabiner";
    manager = "${parentAppDir}/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager";
    daemonBin = "${driver}/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Daemon";

    kanataArgs = [
        "${pkgs.kanata}/bin/kanata"
        "--cfg"
        "${./kanata.kbd}"
        "--port"
        "6666"
    ];

    # Scoped to some users: kanata runs only while one of them is the console (GUI) user, so
    # someone else's fast-user-switched session gets the plain keyboard.
    isUser = lib.concatMapStringsSep "|" lib.escapeShellArg who.names;
    scopedKanata = pkgs.writeShellScript "kanata-for-user" ''
        console_user() { /usr/bin/stat -f %Su /dev/console; }
        is_user() { case "$(console_user)" in ${isUser}) return 0 ;; esac; return 1; }

        while true; do
          if is_user; then
            ${lib.escapeShellArgs kanataArgs} &
            pid=$!
            while kill -0 "$pid" 2>/dev/null && is_user; do
              /bin/sleep 2
            done
            kill "$pid" 2>/dev/null
            wait "$pid" 2>/dev/null
          else
            /bin/sleep 2
          fi
        done
    '';
in
{
    config = lib.mkIf who.any {
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
            ProgramArguments = if who.scoped then [ "${scopedKanata}" ] else kanataArgs;
            RunAtLoad = true;
            KeepAlive = true;
            StandardErrorPath = "/var/log/kanata.log";
        };
    };
}
