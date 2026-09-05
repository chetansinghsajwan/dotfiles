{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
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
          default = 1.33;
        };
      };
    };

    features = {
      dev = mkOption {
        type = types.bool;
        default = true;
        description = "Enable dev tools (vscode, git, neovim).";
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
        default = [ ];
        description = "Extra groups for the system user, set per-host.";
      };

      isWsl = mkOption {
        type = types.bool;
        default = false;
        description = "Whether the system is running under WSL.";
      };
    };

    desktop = {
      gnome = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
      };
    };
  };
}
