{ config, lib, ... }:
let
    who = import ./users.nix lib config.dotfiles.users;
    isUser = lib.concatMapStringsSep " || " (n: ''subject.user == "${n}"'') who.names;
in
{
    config = lib.mkIf who.any {
        services.kanata = {
            enable = true;
            # port is read by pkgs/kb (its default kanata address) to
            # follow layer changes over kanata's TCP server; keep the two in sync.
            keyboards.main = {
                configFile = ./kanata.kbd;
                port = 6666;
            };
        };

        # Scoped to some users: the system service is not started at boot. Those users'
        # sessions start and stop it instead (home/programs/kanata.nix), which polkit
        # allows for this one unit only.
        systemd.services.kanata-main.wantedBy = lib.mkIf who.scoped (lib.mkForce [ ]);
        security.polkit.extraConfig = lib.mkIf who.scoped ''
            polkit.addRule(function(action, subject) {
                if (action.id == "org.freedesktop.systemd1.manage-units" &&
                    action.lookup("unit") == "kanata-main.service" &&
                    (${isUser})) {
                    return polkit.Result.YES;
                }
            });
        '';
    };
}
