{ config, lib, ... }:
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
      colors = {
        primary = mkOption {
          type = types.str;
          default = "#282c34";
        };
        background = mkOption {
          type = types.str;
          default = "#1e1e1e";
        };
        foreground = mkOption {
          type = types.str;
          default = "#abb2bf";
        };
        accent = mkOption {
          type = types.str;
          default = "#61afef";
        };
      };

      fonts = {
        mono = mkOption {
          type = types.str;
          default = "JetBrains Mono";
        };
        sans = mkOption {
          type = types.str;
          default = "Poppins";
        };
        size = mkOption {
          type = types.int;
          default = 11;
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
