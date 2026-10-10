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

    # Nerd Font powerline rounded-end caps, used to draw each tab as a pill:
    # left cap's flat edge butts against the filled name segment, right cap
    # mirrors it on the other side.
    pillCapLeft = builtins.fromJSON ''"\ue0b6"'';
    pillCapRight = builtins.fromJSON ''"\ue0b4"'';
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

        # Default tab mode groups h/Left/Up/k -> previous tab, l/Right/Down/j ->
        # next tab. jk is dropped entirely (kanata handles that now); Up/Down are
        # reversed relative to the default so Up goes to the next tab.
        #
        # GoToNextTab/GoToPreviousTab always wrap around at the ends; there's no
        # config option to stop that as of zellij 0.45.0. A `tab_cycle_wrap false`
        # option was proposed upstream but is unmerged: see
        # https://github.com/zellij-org/zellij/pull/4815. Revisit once it lands.
        extraConfig = ''
            keybinds {
                // Default tab mode binds k -> previous tab, j -> next tab; reverse them.
                tab {
                    unbind "j" "k"
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

                upperModes = map llib.toUpperSpc modes;
                upperPaddedModes = llib.alignLeftPad upperModes;

                modeColors = builtins.listToAttrs (
                    map (m: {
                        name = m;
                        value = if m == "normal" then colors.base0B else colors.base09;
                    }) modes
                );

                # Powerline Glyphs
                pg = {
                    leftArrow = builtins.fromJSON ''"\ue0b2"'';
                    rightArrow = builtins.fromJSON ''"\ue0b0"'';
                };
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

                            color_active       "${colors.base0D}"
                            color_inactive     "${colors.base02}"
                            color_text         "${colors.base05}"
                            color_text_active  "${colors.base00}"

                            tab_normal "#[fg=$inactive]${pillCapLeft}#[fg=$text,bg=$inactive]{name}#[fg=$inactive]${pillCapRight}"
                            tab_active "#[fg=${colors.base0E}]${pillCapLeft}#[fg=$text_active,bg=${colors.base0E}]{name}#[fg=${colors.base0E}]${pillCapRight}"

                            datetime "#[fg=$active] {format}"
                            datetime_format "%Y %b %d %H:%M, %a"
                            datetime_timezone "Asia/Kolkata"

                            ${lib.concatStringsSep "\n" (
                                map (m: "mode_${m} \"#[fg=${modeColors.${m}}] ${upperPaddedModes.${m}}\"${pg.rightArrow}") modes
                            )}
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
