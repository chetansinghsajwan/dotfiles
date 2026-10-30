{
    wallpapers,
}:
{
    config,
    lib,
    pkgs,
    ...
}:
let
    inherit (lib) mkOption types;

    userType = types.submodule (
        { config, name, ... }:
        {
            options = {
                username = mkOption {
                    type = types.str;
                    default = name;
                    readOnly = true;
                };

                displayName = mkOption {
                    type = types.str;
                };

                email = mkOption {
                    type = types.str;
                };

                noreplyEmail = mkOption {
                    type = types.str;
                    description = "GitHub-style noreply address, used for git commits by default.";
                };

                homeDir = mkOption {
                    type = types.str;
                    default = config.username;
                };

                git = {
                    email = mkOption {
                        type = types.str;
                        default = config.noreplyEmail;
                    };
                };

                extraGroups = mkOption {
                    type = types.listOf types.str;
                    default = [ "wheel" ];
                };
            };
        }
    );

    defaultUsers = {
        chetansinghsajwan = {
            displayName = "Chetan Singh Sajwan";
            email = "chetansinghsajwan@gmail.com";
            noreplyEmail = "76040441+chetansinghsajwan@users.noreply.github.com";
        };
    };
in
{
    imports = [
        ../local.nix
    ];

    options.dotfiles = {
        users = mkOption {
            default = defaultUsers;
            type = types.attrsOf userType;
            description = "System users, keyed by username. Each gets a home-manager profile.";
        };

        defaultUser = mkOption {
            type = types.raw;
            readOnly = true;
            default = lib.head (lib.attrValues config.dotfiles.users);
            description = "The default user in case default user is required in any case.";
        };

        theme = {
            name = mkOption {
                type = types.str;
                default = "ayu-dark";
            };

            wallpapersDir = mkOption {
                type = types.str;
                default = "${wallpapers}";
                description = "Directory containing all available wallpapers.";
            };

            wallpaper = mkOption {
                type = types.str;
                default = "${config.dotfiles.theme.wallpapersDir}/car1_ai.jpg";
            };

            cursor = {
                theme = {
                    name = mkOption {
                        type = types.str;
                        default = "Adwaita";
                    };
                    pkg = mkOption {
                        type = types.package;
                        default = pkgs.adwaita-icon-theme;
                    };
                    size = mkOption {
                        type = types.int;
                        default = 24;
                    };
                };
            };

            fonts = {
                mono = {
                    name = mkOption {
                        type = types.str;
                        default = "JetBrains Mono Nerd Font";
                    };
                    pkg = mkOption {
                        type = types.package;
                        default = pkgs.nerd-fonts.jetbrains-mono;
                    };
                };
                sans = {
                    name = mkOption {
                        type = types.str;
                        default = "Poppins";
                    };
                    pkg = mkOption {
                        type = types.package;
                        default = pkgs.poppins;
                    };
                };
                serif = {
                    name = mkOption {
                        type = types.str;
                        default = "Poppins";
                    };
                    pkg = mkOption {
                        type = types.package;
                        default = pkgs.poppins;
                    };
                };
                sizes = {
                    applications = mkOption {
                        type = types.int;
                        default = 11;
                    };
                    terminal = mkOption {
                        type = types.int;
                        default = 11;
                    };
                    desktop = mkOption {
                        type = types.int;
                        default = 11;
                    };
                    popups = mkOption {
                        type = types.int;
                        default = 11;
                    };
                };
                rawFontScale = mkOption {
                    type = types.float;
                    default = 1.0;
                };
            };
        };

        # Shared TUI design tokens, exported as JSON for the `ui` crate
        # (home/programs/ui). Colors come from the stylix scheme.
        ui = {
            chrome = {
                border = mkOption {
                    type = types.enum [
                        "rounded"
                        "plain"
                        "double"
                        "thick"
                    ];
                    default = "rounded";
                    description = "Border glyph set for every pane.";
                };
                titles = mkOption {
                    type = types.bool;
                    default = true;
                };
                transparent = mkOption {
                    type = types.bool;
                    default = true;
                    description = "No solid pane background: the terminal's own (translucent) background shows.";
                };
                editorBox = mkOption {
                    type = types.bool;
                    default = true;
                    description = "Draw the editor (tabs and text) in a bordered box like the docks.";
                };
            };
            layout = {
                gap = mkOption {
                    type = types.ints.unsigned;
                    default = 0;
                    description = "Cells between adjacent panes.";
                };
                paddingX = mkOption {
                    type = types.ints.unsigned;
                    default = 1;
                };
                paddingY = mkOption {
                    type = types.ints.unsigned;
                    default = 0;
                };
                sidebarWidth = mkOption {
                    type = types.ints.unsigned;
                    default = 30;
                };
                previewPercent = mkOption {
                    type = types.ints.between 0 100;
                    default = 65;
                };
                popupPercent = mkOption {
                    type = types.ints.between 10 100;
                    default = 80;
                    description = "Size of a popup (a picker over the editor) as a share of the screen.";
                };
                bottomHeight = mkOption {
                    type = types.ints.positive;
                    default = 12;
                    description = "Height of a bottom dock, in rows.";
                };
            };
        };

        features = {
            dev = mkOption {
                type = types.bool;
                default = true;
                description = "Enable dev tools (vscode, git, helix).";
            };
            gui = mkOption {
                type = types.bool;
                default = true;
                description = "Enable desktop GUI apps.";
            };
            gaming = mkOption {
                type = types.bool;
                default = false;
                description = "Enable gaming tools (proton, bottles).";
            };
        };

        shell = {
            program = mkOption {
                type = types.enum [
                    "zsh"
                    "fish"
                    "nushell"
                ];
                default = "zsh";
            };
            theme = mkOption {
                type = types.enum [
                    "starship"
                ];
                default = "starship";
            };
        };

        # System-level user account settings, read by hosts/*/user.nix.
        system = {
            isWsl = mkOption {
                type = types.bool;
                default = false;
                description = "Whether the system is running under WSL.";
            };

            isLinux = mkOption {
                type = types.bool;
                default = false;
                description = "Whether the system is a Linux system.";
            };

            isDarwin = mkOption {
                type = types.bool;
                default = false;
                description = "Whether the system is a macOS (Darwin) system.";
            };

            displayManager = mkOption {
                type = types.enum [
                    "gdm"
                    "sddm"
                ];
                default = "sddm";
                description = "Display manager to use.";
            };

            stateVersion = {
                linux = mkOption {
                    type = types.str;
                    default = "23.05";
                    description = "system.stateVersion for NixOS hosts.";
                };

                darwin = mkOption {
                    type = types.int;
                    default = 6;
                    description = "system.stateVersion for nix-darwin hosts.";
                };
            };
        };

        desktop = {
            gnome = {
                enable = mkOption {
                    type = types.bool;
                    default = false;
                };
            };
            hyprland = {
                enable = mkOption {
                    type = types.bool;
                    default = false;
                };

                shell = mkOption {
                    type = types.enum [
                        "custom"
                        "caelestia"
                    ];
                    default = "caelestia";
                    description = "Which desktop shell ecosystem to use on top of Hyprland.";
                };
            };
        };

        terminal = {
            default = mkOption {
                type = types.enum [
                    "ghostty"
                    "kitty"
                ];
                default = "ghostty";
            };
        };

        programs = {
            docker = {
                enable = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Whether Docker is enabled — both the system service and home-manager shell integration.";
                };
            };

            kanata-layer-indicator = {
                enable = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Whether the kanata layer indicator is enabled — both the home-manager service and the system group/udev rule it needs to read kanata's output device.";
                };
            };
        };

        editor = {
            terminal = mkOption {
                type = types.enum [
                    "helix"
                ];
                default = "helix";
                description = "Terminal editor used as the default $EDITOR (and for git).";
            };

            helixFork = mkOption {
                type = types.bool;
                default = true;
                description = "Use our helix fork (home/helix, with the shared pick picker) instead of the nixpkgs helix.";
            };

            leader = mkOption {
                type = types.str;
                default = "space";
                description = "Key that opens the leader menu in the helix fork; docks pass it through even when focused.";
            };

            docks = {
                left = mkOption {
                    type = types.listOf types.str;
                    default = [ "files" ];
                    description = "Panels in the left dock of the helix fork (files, git, diagnostics).";
                };
                right = mkOption {
                    type = types.listOf types.str;
                    default = [ "git" ];
                    description = "Panels in the right dock of the helix fork (files, git, diagnostics).";
                };
                bottom = mkOption {
                    type = types.listOf types.str;
                    default = [ "diagnostics" ];
                    description = "Panels in the bottom dock of the helix fork (files, git, diagnostics).";
                };
            };

            scroll_lines = mkOption {
                type = types.int;
                default = 5;
            };

            line_number = mkOption {
                type = types.enum [
                    "absolute"
                    "reative"
                ];
                default = "absolute";
            };

            text_width = mkOption {
                type = types.int;
                default = 100;
            };

            rulers = mkOption {
                type = types.listOf types.int;
                default = [ config.dotfiles.editor.text_width ];
            };
        };
    };
}
