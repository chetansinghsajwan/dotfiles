# Loads a base16 scheme YAML file (same format as nixpkgs' own
# base16-schemes, and what this directory's *.yaml files use) into the
# named-color palette shape pkgs/<name>/module.nix's `colors` options
# expect: { base00 = "#hex"; ...; base07 = "#hex"; red; orange; yellow;
# green; cyan; blue; magenta; brown; } - the same base08-base0F -> named
# color mapping Stylix itself uses.
{ pkgs }:
path:
let
  json = pkgs.runCommand "base16-scheme.json" { } ''
    ${pkgs.remarshal}/bin/yaml2json ${path} "$out"
  '';
  inherit ((builtins.fromJSON (builtins.readFile json))) palette;
in
palette
// {
  red = palette.base08;
  orange = palette.base09;
  yellow = palette.base0A;
  green = palette.base0B;
  cyan = palette.base0C;
  blue = palette.base0D;
  magenta = palette.base0E;
  brown = palette.base0F;
}
