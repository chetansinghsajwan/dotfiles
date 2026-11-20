{
    config,
    pkgs,
    lib,
    llib,
    lpkgs,
    ...
}:
llib.mkToggleModule config "clipboard" {
    home.file = {
        ".config/clipboard-pick/clipboard.sh".source = ./clipboard.sh;
        ".config/clipboard-pick/clipboard.zsh".source = ./clipboard.zsh;
    };

    # wl-clipboard is what `cb` reads and writes the clipboard with (the `cb` tool itself comes
    # from crates.nix).
    home.packages = [pkgs.wl-clipboard];

    programs.bash.initExtra = ''
        source ~/.config/clipboard-pick/clipboard.sh
    '';
    # clipboard.zsh (ZLE widgets/bindkey) is zsh-only, so it isn't sourced into bash.
    programs.zsh.initContent = ''
        source ~/.config/clipboard-pick/clipboard.sh
        source ~/.config/clipboard-pick/clipboard.zsh
    '';

    # `cb watch` records each copy by polling `wl-paste`, which works on WSLg too (its compositor
    # has no data-control protocol, so `wl-paste --watch` and cliphist cannot run there). A service
    # rather than a Hyprland startup command, so it runs on every Linux host; it retries until a
    # Wayland session exists.
    systemd.user.services.cb-watch = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        Unit.Description = "Record the clipboard history for cb";
        Install.WantedBy = ["default.target"];
        Service = {
            ExecStart = "${lpkgs.packages.${pkgs.stdenv.hostPlatform.system}.cb}/bin/cb watch";
            Environment = "PATH=${lib.makeBinPath [pkgs.wl-clipboard]}";
            Restart = "always";
            RestartSec = 5;
        };
    };
}
