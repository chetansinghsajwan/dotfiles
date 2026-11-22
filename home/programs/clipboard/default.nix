{
    config,
    pkgs,
    lib,
    llib,
    lpkgs,
    ...
}: let
    inherit (pkgs.stdenv.hostPlatform) isLinux isDarwin;
    cb = lpkgs.packages.${pkgs.stdenv.hostPlatform.system}.cb;
    # wl-clipboard and xclip only exist on Linux.
    clipboardTools = lib.optionals isLinux [pkgs.wl-clipboard pkgs.xclip];
in
    llib.mkToggleModule config "clipboard" {
        home.file = {
            ".config/clipboard-pick/clipboard.sh".source = ./clipboard.sh;
            ".config/clipboard-pick/clipboard.zsh".source = ./clipboard.zsh;
        };

        # `cb` reads and writes the clipboard through the platform's own tools (the `cb` tool itself
        # comes from crates.nix): wl-clipboard on Wayland and WSLg, xclip on X11, pbpaste/pbcopy on
        # macOS (part of the system).
        home.packages = clipboardTools;

        programs.bash.initExtra = ''
            source ~/.config/clipboard-pick/clipboard.sh
        '';
        # clipboard.zsh (ZLE widgets/bindkey) is zsh-only, so it isn't sourced into bash.
        programs.zsh.initContent = ''
            source ~/.config/clipboard-pick/clipboard.sh
            source ~/.config/clipboard-pick/clipboard.zsh
        '';

        # `cb watch` records each copy by polling the clipboard tool, which works on WSLg too (its
        # compositor has no data-control protocol, so `wl-paste --watch` and cliphist cannot run
        # there) and on macOS (no change event for a command-line tool). A service rather than a
        # Hyprland startup command, so it runs on every host. It keeps polling and logs once when the
        # clipboard is unreachable, so it recovers by itself when the session comes up. It needs no
        # `WAYLAND_DISPLAY`: `cb` falls back to the `wayland-0` socket, which a user service on WSLg
        # does not inherit the variable for.
        systemd.user.services.cb-watch = lib.mkIf isLinux {
            Unit.Description = "Record the clipboard history for cb";
            Install.WantedBy = ["default.target"];
            Service = {
                ExecStart = "${cb}/bin/cb watch";
                Environment = "PATH=${lib.makeBinPath clipboardTools}";
                Restart = "always";
                RestartSec = 5;
            };
        };

        # The macOS counterpart of the service above; pbpaste lives in /usr/bin.
        launchd.agents.cb-watch = lib.mkIf isDarwin {
            enable = true;
            config = {
                ProgramArguments = ["${cb}/bin/cb" "watch"];
                EnvironmentVariables.PATH = "/usr/bin:/bin";
                RunAtLoad = true;
                KeepAlive = true;
            };
        };
    }
