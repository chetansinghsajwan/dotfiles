# nix-wrapper-modules doesn't ship a native zed-editor wrapper module, so
# this is the generic mechanism a native one would provide: settings.json/
# keymap.json/tasks.json generated from plain Nix values, matching zed's
# own on-disk config format. `extensions` mirrors home-manager's own
# programs.zed-editor.extensions option: zed installs these itself at
# runtime (from its extension marketplace) rather than Nix fetching them,
# so this just merges them into settings.json's `auto_install_extensions`.
{
  config,
  lib,
  pkgs,
  wlib,
  ...
}:
{
  imports = [ wlib.modules.default ];

  options.userSettings = lib.mkOption {
    type = lib.types.attrs;
    default = { };
    description = "Content of zed's settings.json.";
  };

  options.userKeymaps = lib.mkOption {
    type = lib.types.listOf lib.types.attrs;
    default = [ ];
    description = "Content of zed's keymap.json.";
  };

  options.userTasks = lib.mkOption {
    type = lib.types.listOf lib.types.attrs;
    default = [ ];
    description = "Content of zed's tasks.json.";
  };

  options.extensions = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Extensions for zed to auto-install from its marketplace on startup.";
  };

  config = {
    package = lib.mkDefault pkgs.zed-editor;

    constructFiles = {
      settings = {
        relPath = "zed-config/settings.json";
        content = builtins.toJSON (
          config.userSettings
          // lib.optionalAttrs (config.extensions != [ ]) {
            auto_install_extensions = lib.genAttrs config.extensions (_: true);
          }
        );
      };
    }
    // lib.optionalAttrs (config.userKeymaps != [ ]) {
      keymap = {
        relPath = "zed-config/keymap.json";
        content = builtins.toJSON config.userKeymaps;
      };
    }
    // lib.optionalAttrs (config.userTasks != [ ]) {
      tasks = {
        relPath = "zed-config/tasks.json";
        content = builtins.toJSON config.userTasks;
      };
    };
  };
}
