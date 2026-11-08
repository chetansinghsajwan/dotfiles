{
    config,
    pkgs,
    lib,
    llib,
    lpkgs,
    ...
}:
let
    # zellij-forgot shows a floating keybind cheatsheet on demand; the built-in
    # compact-bar tooltip is broken on zellij >=0.44.1 (zellij-org/zellij#5229).
    zellij-forgot = pkgs.fetchurl {
        url = "https://github.com/karimould/zellij-forgot/releases/download/0.4.2/zellij_forgot.wasm";
        sha256 = "1ns9wjn1ncjapqpp9nn9kyhqydvl0fbnyiavd0lc3gcxa52l269i";
    };

    colors = config.lib.stylix.colors.withHashtag;

    kb = lpkgs.packages.${pkgs.stdenv.hostPlatform.system}.kb;

    # kanata (run with --port 6666) is followed by `kb daemon`, which serves the
    # keyboard state on 127.0.0.1:6667; the bar listener pushes each layer change
    # into zjstatus. 127.0.0.1 needs WSL mirrored networking
    # (networkingMode=mirrored in .wslconfig) when kanata runs on the Windows
    # host; override with KANATA_HOST otherwise.
    kbListener = pkgs.writeShellScript "kb-zellij-listen" ''
        set -uo pipefail

        ${kb}/bin/kb watch --format layer | while IFS= read -r layer; do
          for s in $(${pkgs.zellij}/bin/zellij list-sessions -ns 2>/dev/null); do
            ${pkgs.zellij}/bin/zellij --session "$s" pipe "zjstatus::pipe::pipe_kanata::$layer" </dev/null >/dev/null 2>&1 &
          done
        done
    '';

    kbDaemon = pkgs.writeShellScript "kb-daemon" ''
        exec ${kb}/bin/kb daemon --kanata "''${KANATA_HOST:-127.0.0.1}:6666"
    '';

in
{
    programs.zellij = {
        settings = {
            show_startup_tips = false;
        };

        # enableBashIntegration = config.dotfiles.shell.program == "bash";
        # enableZshIntegration = config.dotfiles.shell.program == "zsh";
        # enableFishIntegration = config.dotfiles.shell.program == "fish";
        # exitShellOnExit = true;

        # Default tab mode binds h/Left/Up/k -> previous tab, l/Right/Down/j ->
        # next tab. We reverse k/j and Up/Down here so Up/k go to the next tab
        # and Down/j go to the previous tab; h/Left/l/Right keep their defaults.
        #
        # GoToNextTab/GoToPreviousTab always wrap around at the ends; there's no
        # config option to stop that as of zellij 0.45.0. A `tab_cycle_wrap false`
        # option was proposed upstream but is unmerged: see
        # https://github.com/zellij-org/zellij/pull/4815. Revisit once it lands.
        extraConfig = ''
            ui {
                pane_frames {
                    rounded_corners ${lib.boolToString (config.dotfiles.ui.chrome.border == "rounded")}
                }
            }
            keybinds {
                // Default tab mode binds k -> previous tab, j -> next tab; reverse them.
                tab {
                    bind "k" { GoToNextTab; }
                    bind "j" { GoToPreviousTab; }
                    bind "Up" { GoToNextTab; }
                    bind "Down" { GoToPreviousTab; }
                }

                // Move mode lives on Alt+m instead of Ctrl+h (Ctrl+h is Backspace in terminals).
                shared_except "move" "locked" {
                    unbind "Ctrl h"
                    bind "Alt m" { SwitchToMode "Move"; }
                }
                move {
                    unbind "Ctrl h"
                    bind "Alt m" { SwitchToMode "Normal"; }
                }

                // Ctrl+/ avoids colliding with typing a literal "?" in a pane.
                shared_except "locked" {
                    bind "Ctrl /" {
                        LaunchOrFocusPlugin "file:${zellij-forgot}" {
                            floating true
                        }
                    }
                }
            }
        '';

        # zjstatus replaces the built-in compact-bar to get pill-shaped tabs -
        # tab shape isn't configurable in zellij's own tab-bar/compact-bar,
        # only colors are themeable there. Trade-off: compact-bar also showed
        # contextual keybinding hints inline; zjstatus has no equivalent
        # widget, so that's gone from the bar - zellij-forgot (Ctrl+/, above)
        # covers it on demand instead.
        layouts.default =
            let
                modes = [
                    "normal"
                    "locked"
                    "pane"
                    "tab"
                    "resize"
                    "scroll"
                    "search"
                    "enter_search"
                    "session"
                    "move"
                    "rename_tab"
                    "rename_pane"
                    "prompt"
                    "tmux"
                ];

                tabs = [
                    "normal"
                    "active"
                ];

                maxModesLen = llib.maxStringLen modes;
                upperPaddedModes = lib.genAttrs modes (m: llib.padRight (llib.toUpperSpc m) maxModesLen);
                ribbonColor = colors.base02;
                leftEnd = pg.softRight;
                leftContinue = pg.softLeft;
                pg = llib.powerlineGlyphs;

                mkModeLine =
                    m:
                    let
                        modeColor = if m == "normal" then "$mode_normal" else "$mode";
                    in
                    ''
                        mode_${m} "#[fg=${ribbonColor}]${leftContinue}#[fg=${modeColor},bg=${ribbonColor}] ${upperPaddedModes.${m}}#[fg=${ribbonColor}]${leftEnd}"
                    '';

                mkTabLine =
                    t:
                    let
                        fg = if t == "active" then "$ribbon_active_fg" else "$ribbon_fg";
                        bg = if t == "active" then "$ribbon_active_bg" else "$ribbon_bg";
                    in
                    ''
                        tab_${t} "#[fg=${bg}]${leftContinue}#[fg=${fg},bg=${bg},bold] {name} #[fg=${bg}]${leftEnd}"
                    '';
            in
            ''
                layout {
                    pane size=1 borderless=true {
                        plugin location="file:${pkgs.zellijPlugins.zjstatus}" {
                            format_left "{mode} {tabs}"
                            format_right "{pipe_kanata} {datetime}"

                            border_enabled "false"
                            hide_frame_for_single_pane "true"

                            tab_separator " "

                            color_mode "${colors.base09}"
                            color_mode_normal "${colors.base0B}"
                            color_active "${colors.base0D}"
                            color_ribbon_fg "${colors.base05}"
                            color_ribbon_bg "${colors.base02}"
                            color_ribbon_active_fg "${colors.base00}"
                            color_ribbon_active_bg "${colors.base0E}"

                            ${lib.concatStringsSep "\n" (map mkModeLine modes)}
                            ${lib.concatStringsSep "\n" (map mkTabLine tabs)}

                            pipe_kanata_format "#[fg=${ribbonColor}]${leftContinue}#[fg=$mode_normal,bg=${ribbonColor},bold] {output}#[fg=${ribbonColor},bg=default,nobold]${leftEnd}"
                            pipe_kanata_rendermode "static"

                            datetime "#[fg=$active] {format}"
                            datetime_format "%Y %b %d %H:%M, %a"
                            datetime_timezone "Asia/Kolkata"
                        }
                    }
                    pane
                }
            '';
    };

    systemd.user.services = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        kb-daemon = {
            Unit.Description = "Keyboard status (kanata layer) served to terminal tools";
            Install.WantedBy = [ "default.target" ];
            Service = {
                ExecStart = "${kbDaemon}";
                Restart = "on-failure";
                RestartSec = 2;
            };
        };

        kb-zellij-listen = {
            Unit = {
                Description = "Push the keyboard layer into the zellij bar";
                After = [ "kb-daemon.service" ];
            };
            Install.WantedBy = [ "default.target" ];
            Service = {
                ExecStart = "${kbListener}";
                Restart = "on-failure";
                RestartSec = 2;
            };
        };
    };

    home.shellAliases = {
        z = "zellij";
    };
}
