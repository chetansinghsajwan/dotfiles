{
    config,
    pkgs,
    lib,
    llib,
    zjstatus,
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
                    rounded_corners true
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

                // Ctrl+/ avoids colliding with typing a literal "?" in a pane.
                shared_except "locked" {
                    bind "Ctrl /" {
                        LaunchOrFocusPlugin "file:~/zellij-plugins/zellij_forgot.wasm" {
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
                leftEnd = pg.circleRight;
                leftContinue = pg.circleLeft;
                pg = llib.powerlineGlyphs;

                mkModeLine =
                    m:
                    let
                        modeColor = if m == "normal" then "$mode_normal" else "$mode";
                    in
                    ''
                        mode_${m} "#[fg=${modeColor},bg=${ribbonColor}] ${upperPaddedModes.${m}}#[fg=${ribbonColor}]${leftEnd}"
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
                        plugin location="file:~/zellij-plugins/zjstatus.wasm" {
                            format_left "{mode} {tabs}"
                            format_right "{datetime}"

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

                            datetime "#[fg=$active] {format}"
                            datetime_format "%Y %b %d %H:%M, %a"
                            datetime_timezone "Asia/Kolkata"
                        }
                    }
                    pane
                }
            '';
    };

    home.file."zellij-plugins/zellij_forgot.wasm".source = zellij-forgot;
    home.file."zellij-plugins/zjstatus.wasm".source = zjstatus;

    home.shellAliases = {
        z = "zellij";
    };
}
