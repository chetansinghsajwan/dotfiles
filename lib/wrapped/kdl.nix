# Minimal Nix -> KDL renderer, shared by the wrapped-package flakes under
# pkgs/ that speak KDL (currently just zellij, for config.kdl and its
# layouts).
#
# A KDL node is { node = "name"; args ? [ ]; props ? { }; children ? [ ]; }:
#   - `args` are positional values, rendered in order (e.g. `bind "Up"`).
#   - `props` are key=value pairs (e.g. `pane size=1 borderless=true`).
#   - `children` is a list of nested nodes, rendered in a `{ ... }` block.
# A "document" is just a list of top-level nodes.
{ lib }:
let
  renderValue =
    v:
    if builtins.isBool v then
      (if v then "true" else "false")
    else if builtins.isInt v || builtins.isFloat v then
      toString v
    else if builtins.isString v then
      builtins.toJSON v
    else
      throw "lib/wrapped/kdl.nix: unsupported KDL value: ${builtins.toJSON v}";

  renderNode =
    indent:
    {
      node,
      args ? [ ],
      props ? { },
      children ? [ ],
    }:
    let
      argsStr = lib.concatMapStringsSep " " renderValue args;
      propsStr = lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "${k}=${renderValue v}") props);
      head = lib.concatStringsSep " " (
        [ node ] ++ lib.optional (argsStr != "") argsStr ++ lib.optional (propsStr != "") propsStr
      );
    in
    if children == [ ] then
      "${indent}${head}\n"
    else
      "${indent}${head} {\n" + renderNodes (indent + "    ") children + "${indent}}\n";

  renderNodes = indent: nodes: lib.concatMapStrings (renderNode indent) nodes;
in
{
  inherit renderNode;
  renderDocument = nodes: renderNodes "" nodes;
}
