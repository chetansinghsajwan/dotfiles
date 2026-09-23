{ lib }:
{
  # Shared helpers for the wrapped-package flakes under pkgs/ (base16
  # template substitution, KDL rendering, CLI-flags rendering).
  wrapped = import ./wrapped { inherit lib; };

  # Shared home-manager wiring for a host's default.nix — keeps
  # useUserPackages/backupFileExtension/etc. from drifting between hosts.
  mkHomeManagerModule =
    {
      username,
      imports,
      extraSpecialArgs ? { },
    }:
    {
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "bak";
      home-manager.overwriteBackup = true;
      home-manager.extraSpecialArgs = extraSpecialArgs;
      home-manager.users.${username}.imports = imports;
    };

  mkToggleModule = config: name: body: {
    options.dotfiles.programs.${name}.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    config = lib.mkIf config.dotfiles.programs.${name}.enable body;
  };

  importDir =
    dir:
    let
      entries = builtins.readDir dir;
    in
    builtins.map (name: dir + "/${name}") (
      builtins.filter (
        name:
        entries.${name} == "regular" && builtins.match ".*\\.nix" name != null && name != "default.nix"
      ) (builtins.attrNames entries)
    );
}
