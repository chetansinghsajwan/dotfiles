{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.dotfiles = {

    user = {
      username = mkOption {
        type = types.str;
        default = "chetansinghsajwan";
        description = "Primary OS/HM username.";
      };

      email = mkOption {
        type = types.str;
        default = "76040441+chetansinghsajwan@users.noreply.github.com";
      };

      homeDirectory = mkOption {
        type = types.str;
        default = "/home/chetansinghsajwan";
      };

      stateVersion = mkOption {
        type = types.str;
        default = "23.11";
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

    programs = {
      firefox.enable = mkOption {
        type = types.bool;
        default = true;
      };
      vscode.enable = mkOption {
        type = types.bool;
        default = true;
      };
      gnomeDesktop.enable = mkOption {
        type = types.bool;
        default = true;
      };
      terminal = mkOption {
        type = types.enum [
          "ghostty"
          "gnome-terminal"
        ];
        default = "ghostty";
      };
    };

    shell = {
      program = mkOption {
        type = types.enum [
          "zsh"
          "fish"
          "nu"
        ];
        default = "zsh";
      };
      theme = mkOption {
        type = types.enum [
          "powerlevel10k"
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
  };
}
