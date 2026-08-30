_: { }

# { pkgs, ... }:
# {
#   programs.vscode = {
#     enable = true;
#     package = pkgs.vscodium-fhs;
#     enableUpdateCheck = false;
#     enableExtensionUpdateCheck = false;
#     mutableExtensionsDir = false;

#     userSettings = import ./settings.nix;
#     userTasks = import ./tasks.nix;
#     keybindings = import ./keybindings.nix;
#   };

#   imports = [
#     ./languages/cpp.nix
#     ./languages/c.nix
#     ./languages/html.nix
#     ./languages/json.nix
#     ./languages/nix.nix

#     ./features/clangd.nix
#     ./features/cmake.nix
#     ./features/lldb.nix

#     ./themes/material-icons.nix
#     ./themes/one-dark-pro.nix
#     ./themes/github.nix
#   ];
# }
