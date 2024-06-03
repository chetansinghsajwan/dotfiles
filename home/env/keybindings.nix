{ ... }:
{
    dconf.settings."org/gnome/desktop/wm/keybindings" = {
        "activate-window-menu"         = [];
        "always-on-top"                = [];
        "begin-move"                   = [];
        "begin-resize"                 = [];
        "close"                        = [ "<Super>q" ];
        "cycle-group"                  = [];
        "cycle-group-backward"         = [];
        "cycle-panels"                 = [];
        "cycle-panels-backward"        = [];
        "cycle-windows"                = [];
        "cycle-windows-backward"       = [];
        "lower"                        = [];
        "maximize"                     = [ "<Super>Up" ];
        "maximize-horizontally"        = [];
        "maximize-vertically"          = [];
        "minimize"                     = [ "<Super>h" ];
        "unmaximize"                   = [ "<Super>Down" ];
        "move-to-center"               = [ "<Super>c" ];
        "move-to-corner-ne"            = [];
        "move-to-corner-nw"            = [];
        "move-to-corner-se"            = [];
        "move-to-corner-sw"            = [];
        "move-to-monitor-down"         = [];
        "move-to-monitor-left"         = [];
        "move-to-monitor-right"        = [];
        "move-to-monitor-up"           = [];
        "move-to-side-e"               = [];
        "move-to-side-n"               = [];
        "move-to-side-s"               = [];
        "move-to-side-w"               = [];
        "move-to-workspace-1"          = [];
        "move-to-workspace-2"          = [];
        "move-to-workspace-3"          = [];
        "move-to-workspace-4"          = [];
        "move-to-workspace-5"          = [];
        "move-to-workspace-6"          = [];
        "move-to-workspace-7"          = [];
        "move-to-workspace-8"          = [];
        "move-to-workspace-9"          = [];
        "move-to-workspace-10"         = [];
        "move-to-workspace-11"         = [];
        "move-to-workspace-up"         = [ "<Super><Ctrl><Shift>Up" ];
        "move-to-workspace-down"       = [ "<Super><Ctrl><Shift>Down" ];
        "move-to-workspace-left"       = [ "<Super><Ctrl><Shift>Left" ];
        "move-to-workspace-right"      = [ "<Super><Ctrl><Shift>Right" ];
        "move-to-workspace-last"       = [];
        "panel-main-menu"              = [];
        "panel-run-dialog"             = [];
        "raise"                        = [];
        "raise-or-lower"               = [];
        "set-spew-mark"                = [];
        "show-desktop"                 = [ "<Super>d" ];
        "switch-applications"          = [ "<Super>Tab" ];
        "switch-applications-backward" = [ "<Shift><Super>Tab" ];
        "switch-group"                 = [];
        "switch-group-backward"        = [];
        "switch-input-source"          = [];
        "switch-input-source-backward" = [];
        "switch-panels"                = [];
        "switch-panels-backward"       = [];
        "switch-to-workspace-1"        = [];
        "switch-to-workspace-2"        = [];
        "switch-to-workspace-3"        = [];
        "switch-to-workspace-4"        = [];
        "switch-to-workspace-5"        = [];
        "switch-to-workspace-6"        = [];
        "switch-to-workspace-7"        = [];
        "switch-to-workspace-8"        = [];
        "switch-to-workspace-9"        = [];
        "switch-to-workspace-10"       = [];
        "switch-to-workspace-11"       = [];
        "switch-to-workspace-up"       = [ "<Super><Ctrl>Up" ];
        "switch-to-workspace-down"     = [ "<Super><Ctrl>Down" ];
        "switch-to-workspace-left"     = [ "<Super><Ctrl>Left" ];
        "switch-to-workspace-right"    = [ "<Super><Ctrl>Right" ];
        "switch-to-workspace-last"     = [];
        "switch-windows"               = [];
        "switch-windows-backward"      = [];
        "toggle-above"                 = [];
        "toggle-fullscreen"            = [ "<Super>f" ];
        "toggle-maximized"             = [];
        "toggle-on-all-workspaces"     = [];
    };

    dconf.settings."org/gnome/mutter/keybindings" = {
        "toggle-tiled-left" = "<Super>Left";
        "toggle-tiled-right" = "<Super>Right";
    };

    dconf.settings."org/gnome/settings-daemon/plugins/media-keys" = {
        "power" = [];
        "logout" = [];
        "screenreader" = [];
        "screensaver" = [];
        "suspend" = [];
        "touchpad-off" = [];
        "touchpad-on" = [];
        "touchpad-toggle" = [];
        "screen-brightness-up" = [ "<Super>]" ];
        "screen-brightness-down" = [ "<Super>[" ];
        "screen-brightness-cycle" = [];
        "rfkill" = [];
        "rfkill-bluetooth" = [];
        "rotate-video-back" = [];
        "increase-text-size" = [];
        "decrease-text-size" = [];
        "keyboard-brightness-up" = [];
        "keyboard-brightness-down" = [];
        "keyboard-brightness-toggle" = [];
        "on-screen-keyboard" = [];
        "toggle-contrast" = [];

        "battery-status" = [];
        "calculator" = [];
        "control-center" = [];
        "eject" = [];
        "email" = [];
        "help" = [];
        "home" = [];
        "www" = [];
        "search" = [ "<Super>s" ];
        "magnifier" = [];
        "magnifier-zoom-in" = [];
        "magnifier-zoom-out" = [];
        "media" = [];

        "pause" = [ "<Super>p" ];
        "play" = [];
        "stop" = [];
        "playback-forward" = [];
        "playback-backward" = [];
        "playback-random" = [];
        "playback-repeat" = [];
        "playback-rewind" = [];
        "next" = [];
        "previous" = [];
        "volume-up" = [ "<Super>'" ];
        "volume-up-precise" = [];
        "volume-up-quiet" = [];
        "volume-down" = [ "<Super>;" ];
        "volume-down-precise" = [];
        "volume-down-quiet" = [];
        "volume-mute" = [];
        "volume-mute-quiet" = [];
        "volume-step" = 6;
        "mic-mute" = [];

        "custom-keybindings" = [];
    };

    dconf.settings."org/gnome/shell/keybindings" = {
        "switch-to-application-1" = [];
        "switch-to-application-2" = [];
        "switch-to-application-3" = [];
        "switch-to-application-4" = [];
        "switch-to-application-5" = [];
        "switch-to-application-6" = [];
        "switch-to-application-7" = [];
        "switch-to-application-8" = [];
        "switch-to-application-9" = [];

        "open-new-window-application-1" = [];
        "open-new-window-application-2" = [];
        "open-new-window-application-3" = [];
        "open-new-window-application-4" = [];
        "open-new-window-application-5" = [];
        "open-new-window-application-6" = [];
        "open-new-window-application-7" = [];
        "open-new-window-application-8" = [];
        "open-new-window-application-9" = [];

        "screenshot" = [];
        "screenshot-window" = [];
        "show-screenshot-ui" = [];
        "show-screen-recording-ui" = [];

        "shift-overview-up" = [];
        "shift-overview-down" = [];

        "focus-active-notification" = [];
        "toggle-message-tray" = [];
        "toggle-overview" = [];
        "toggle-application-view" = [];
        "toggle-quick-settings" = [];
    };

    dconf.settings."org/gnome/mutter/wayland/keybindings" = {
        "restore-shortcuts" = [];
    };
}
