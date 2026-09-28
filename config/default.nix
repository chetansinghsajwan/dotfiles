{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  wallpapers = pkgs.fetchFromGitHub {
    name = "wallpapers";
    owner = config.dotfiles.user.username;
    repo = "wallpapers";
    rev = "dev";
    hash = "sha256-HKoevYMAEE7kjkEArAmbcJj/tmHq9QHUSRy0aF2zAfk=";
  };
in
{
  options.dotfiles = {

    user = {
      displayName = mkOption {
        type = types.str;
        default = "Chetan Singh Sajwan";
      };

      username = mkOption {
        type = types.str;
        default = "chetansinghsajwan";
      };

      email = mkOption {
        type = types.str;
        default = "chetansinghsajwan@gmail.com";
      };

      noreplyEmail = mkOption {
        type = types.str;
        default = config.dotfiles.user.email;
      };

      homeDir = mkOption {
        type = types.str;
        default = config.dotfiles.user.username;
      };

      stateVersion = mkOption {
        type = types.str;
        default = "23.11";
      };

      git = {
        email = mkOption {
          type = types.str;
          default = "76040441+chetansinghsajwan@users.noreply.github.com";
        };
      };
    };

    theme = {
      name = mkOption {
        type = types.str;
        default = "ayu-dark";
      };

      # base16 palette derived from `name`, loaded from nixpkgs' own
      # base16-schemes package (the same one home/modules/stylix.nix
      # points Stylix at) via remarshal's yaml2json - Nix has no native
      # YAML parser - and expanded into named colors the same way Stylix
      # does (base08-base0F -> red/orange/yellow/green/cyan/blue/
      # magenta/brown). Packages that wrap themselves away from
      # home-manager (see pkgs/<name>/module.nix) read this directly
      # (via a standalone evalModules over this file alone) as their own
      # default theme, instead of duplicating this logic themselves.
      colors = mkOption {
        type = types.attrsOf types.str;
        readOnly = true;
        default =
          let
            inherit ((builtins.fromJSON (
                builtins.readFile (
                  pkgs.runCommand "base16-scheme.json" { } ''
                    ${pkgs.remarshal}/bin/yaml2json ${pkgs.base16-schemes}/share/themes/${config.dotfiles.theme.name}.yaml "$out"
                  ''
                )
              ))) palette;
          in
          palette
          // {
            red = palette.base08;
            orange = palette.base09;
            yellow = palette.base0A;
            green = palette.base0B;
            cyan = palette.base0C;
            blue = palette.base0D;
            magenta = palette.base0E;
            brown = palette.base0F;
          };
        description = ''
          base16 palette as { base00 = "#hex"; ...; cyan = "#hex"; ... },
          derived from dotfiles.theme.name.
        '';
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
      extraGroups = mkOption {
        type = types.listOf types.str;
        default = [ "wheel" ];
        description = "Extra groups for the system user, set per-host.";
      };

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
    };

    editor = {
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
