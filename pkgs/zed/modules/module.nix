# This repo's own zed customization (base settings + nix/cpp/cmake
# language support, previously spread across zed/default.nix,
# keybindings.nix, and features/{nix,cpp,cmake}.nix) plus
# nix-wrapper-modules' generic wrapper mechanism (wrapper-module.nix,
# since nix-wrapper-modules ships no native zed-editor module) - so this
# one file is the complete zed wrapper, and callers only ever need to
# reference it, not also list wrapper-module.nix separately.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./wrapper-module.nix

    # Purely so `shellProgram` below can default to
    # config.dotfiles.shell.program - the same config/default.nix option
    # this repo's home-manager hosts already get, just merged into this
    # wrapper module's own isolated evalModules instead of
    # home-manager's. pkgs/lib/config are already shared module args, so
    # this needs no separate evalModules call or specialArgs threading.
    ../../../config
  ];

  # A separate option (rather than setting userSettings.terminal.shell.program
  # to a whole computed value directly from outside) since userSettings'
  # own type (plain attrs, not a freeform submodule) requires equal
  # values across definition sites rather than recursively merging them
  # - same reasoning as helix's scrollLines/lineNumber/rulers/textWidth.
  options.shellProgram = lib.mkOption {
    type = lib.types.str;
    default = config.dotfiles.shell.program;
    defaultText = lib.literalExpression "config.dotfiles.shell.program";
    description = "Value for userSettings.terminal.shell.program.";
  };

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
      terminal.shell.program = config.shellProgram;

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
