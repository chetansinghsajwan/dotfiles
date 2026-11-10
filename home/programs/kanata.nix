{
    config,
    lib,
    pkgs,
    ...
}:
let
    who = import ../../hosts/shared/kanata/users.nix lib config.dotfiles.users;
    systemctl = "${pkgs.systemd}/bin/systemctl";
    enabled = config.dotfiles.currentUser.kanata.enable;
in
{
    config = lib.mkMerge [
        # The layout and layers `kanata-status` draws (kanata itself reads the file from the store).
        (lib.mkIf enabled {
            xdg.configFile."kanata/kanata.kbd".source = ../../hosts/shared/kanata/kanata.kbd;
        })

        # Only when kanata is scoped (hosts/shared/kanata/default.nix) and this user has it:
        # their session runs the system service, so it stops at logout and never runs for
        # users without it.
        (lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && who.scoped && enabled) {
            systemd.user.services.kanata = {
                Unit.Description = "Run kanata for this user's session";
                Install.WantedBy = [ "default.target" ];
                Service = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    ExecStart = "${systemctl} start kanata-main.service";
                    ExecStop = "${systemctl} stop kanata-main.service";
                };
            };
        })
    ];
}
