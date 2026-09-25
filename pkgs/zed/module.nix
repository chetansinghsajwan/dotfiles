# This repo's own zed customization (base settings + nix/cpp/cmake
# language support, previously spread across zed/default.nix,
# keybindings.nix, and features/{nix,cpp,cmake}.nix).
# terminal.shell.program is set separately by whatever imports this (see
# flake.nix's `homeModules.default`), since it needs the outer config's
# dotfiles.shell.program - a plain wrapper module like this one only ever
# sees its own submodule config, not the config around it.
{ pkgs, ... }:
{
  config = {
    runtimePkgs = with pkgs; [
      nixd
      nixpkgs-fmt
      llvmPackages_19.clang-tools
      cmake
      ninja
    ];

    extensions = [
      "nix"
      "cmake"
    ];

    userSettings = {
      autosave.after_delay.milliseconds = 1000;
      format_on_save = "on";
      auto_update = false;
      confirm_quit = true;
      remove_trailing_whitespace_on_save = true;
      ensure_final_newline_on_save = true;
      git.inline_blame.enabled = true;

      lsp = {
        nil.settings.formatting.command = [ "nixpkgs-fmt" ];
        clangd = {
          binary.path = "${pkgs.llvmPackages_19.clang-tools}/bin/clangd";
          arguments = [ "--compile-commands-dir=/build" ];
        };
      };

      languages = {
        Nix.language_servers = [ "nil" ];
        "C++".language_servers = [ "clangd" ];
      };
    };

    userKeymaps = [
      {
        context = "Workspace";
        bindings = {
          "ctrl-n" = "workspace::NewFile";
          "ctrl-p" = "command_palette::Toggle";
          "ctrl-shift-p" = null;
          "ctrl-e" = "file_finder::Toggle";
          "ctrl-shift-e" = "project_panel::ToggleFocus";
          "ctrl-shift-i" = "editor::Format";
        };
      }
    ];

    userTasks = [
      {
        label = "cmake build all";
        command = "cmake --build build";
        use_new_terminal = false;
        reveal = "always";
      }
      {
        label = "cmake configure";
        command = "cmake -B build -G Ninja";
        use_new_terminal = false;
        reveal = "always";
      }
    ];
  };
}
