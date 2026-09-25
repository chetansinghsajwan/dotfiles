# nix-wrapper-modules doesn't ship a native vscode wrapper module, so this
# is the generic mechanism a native one would provide: settings.json/
# keybindings.json/tasks.json generated from plain Nix values, plus a
# combined, immutable extensions directory (same buildEnv + extensions.json
# manifest technique home-manager's own programs.vscode module uses under
# the hood, since that part isn't specific to home-manager's typed options -
# it's just "build one derivation out of a list of extension packages").
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
    description = "Content of VS Code's settings.json.";
  };

  options.keybindings = lib.mkOption {
    type = lib.types.listOf lib.types.attrs;
    default = [ ];
    description = "Content of VS Code's keybindings.json.";
  };

  options.userTasks = lib.mkOption {
    type = lib.types.attrs;
    default = { };
    description = "Content of VS Code's tasks.json.";
  };

  options.extensions = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = "Extension packages (e.g. from pkgs.vscode-extensions) to pre-install.";
  };

  options.extensionsDrv = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    description = ''
      Combined, immutable extensions directory (all of `extensions` plus
      the manifest VS Code needs to recognize them as installed) -
      accessible from outside via
      `<builtPackage>.configuration.extensionsDrv`.
    '';
  };

  config = {
    package = lib.mkDefault pkgs.vscode;

    constructFiles = {
      settings = {
        relPath = "vscode-config/settings.json";
        content = builtins.toJSON config.userSettings;
      };
    }
    // lib.optionalAttrs (config.keybindings != [ ]) {
      keybindings = {
        relPath = "vscode-config/keybindings.json";
        content = builtins.toJSON config.keybindings;
      };
    }
    // lib.optionalAttrs (config.userTasks != { }) {
      tasks = {
        relPath = "vscode-config/tasks.json";
        content = builtins.toJSON config.userTasks;
      };
    };

    extensionsDrv = pkgs.buildEnv {
      name = "vscode-extensions";
      paths = config.extensions ++ [
        (pkgs.writeTextFile {
          name = "vscode-extensions-json";
          text = pkgs.vscode-utils.toExtensionJson config.extensions;
          destination = "/share/vscode/extensions/extensions.json";
        })
      ];
    };
  };
}
