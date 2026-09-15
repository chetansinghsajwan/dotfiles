{ lib }:
{
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

  importDirRecurse =
    dir:
    let
      entries = builtins.readDir dir;

      files = builtins.filter (
        name:
        entries.${name} == "regular" && builtins.match ".*\\.nix" name != null && name != "default.nix"
      ) (builtins.attrNames entries);

      dirs = builtins.filter (name: entries.${name} == "directory") (builtins.attrNames entries);

      ownFiles = builtins.map (name: dir + "/${name}") files;
      nestedFiles = builtins.concatMap (name: importDirRec (dir + "/${name}")) dirs;
      importDirRec = import ./importDir.nix { inherit lib; };
    in
    ownFiles ++ nestedFiles;
}
