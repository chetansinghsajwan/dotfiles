# Nix attrset -> CLI flag string renderer, shared by the wrapped-package
# flakes under pkgs/ whose config is really just a flat set of flags
# (currently just fzf, for FZF_DEFAULT_OPTS).
{ lib }:
{
  # Render a settings attrset into a space-separated "--flag value" string.
  #   - list value: the flag repeated once per element (e.g. multiple
  #     --bind entries).
  #   - bool true: a bare "--flag" with no value; bool false: dropped.
  #   - anything else: "--flag value".
  render =
    settings:
    lib.concatStringsSep " " (
      lib.flatten (
        lib.mapAttrsToList (
          name: value:
          if builtins.isList value then
            map (v: "--${name} ${toString v}") value
          else if builtins.isBool value then
            lib.optional value "--${name}"
          else
            "--${name} ${toString value}"
        ) settings
      )
    );
}
