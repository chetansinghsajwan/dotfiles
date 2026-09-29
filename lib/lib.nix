{ nixpkgs }:
let
  lib = nixpkgs.lib;
in rec {
  systems = [
    "x86_64-linux"
    "aarch64-linux"
    "x86_64-darwin"
    "aarch64-darwin"
  ];

  forEachSystem = lib.genAttrs systems;

  # Loads a base16 scheme - the same YAML shape nixpkgs' own base16-schemes
  # ships - into the named-color palette shape consumers actually want:
  # { base00 = "#hex"; ...; base0F = "#hex"; red; orange; yellow; green;
  # cyan; blue; magenta; brown; }. The base08-base0F -> named-color mapping
  # matches what Stylix itself uses.
  getBase16Colors = pkgs: themeName:
    let
      yamlFile = "${pkgs.base16-schemes}/share/themes/${themeName}.yaml";

      json = pkgs.runCommand "base16-scheme.json" {
        nativeBuildInputs = [ pkgs.yq-go ];
      } ''
        yq -o=json '.' ${yamlFile} > $out
      '';

      palette = (builtins.fromJSON (builtins.readFile json)).palette;
    in
    palette // {
      red = palette.base08;
      orange = palette.base09;
      yellow = palette.base0A;
      green = palette.base0B;
      cyan = palette.base0C;
      blue = palette.base0D;
      magenta = palette.base0E;
      brown = palette.base0F;
    };

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
