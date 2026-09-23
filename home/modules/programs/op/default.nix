{
  pkgs,
  op-wrapped,
  ...
}:
{
  # `op` (open): dispatches a file to the right interactive tool - csvlens for
  # CSV/TSV, $EDITOR (falling back to hx) for everything else `file` calls
  # text, "unsupported" otherwise. Installed as a plain PATH binary (not a
  # shell function) so it works identically from an interactive shell and
  # from yazi, mirroring how `pv` previews the same file types.
  home.packages = [
    (op-wrapped.lib.mkOp { inherit pkgs; })
  ];
}
