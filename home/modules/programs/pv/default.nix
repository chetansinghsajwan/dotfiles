{ pkgs, ... }:
{
  # `pv` (preview): dispatches a file to the right terminal renderer - column-
  # aligned tidy-viewer for CSV/TSV, syntax-highlighted bat for everything
  # else bat can read, "unsupported" otherwise. Installed as a plain PATH
  # binary (not a shell function) so it works identically from an interactive
  # shell and from yazi's `piper`, which spawns a bare `sh -c` with no rc
  # sourcing and so can't see shell functions.
  home.packages = [
    (pkgs.writeShellApplication {
      name = "pv";
      runtimeInputs = with pkgs; [
        file
        bat
        tidy-viewer
      ];
      text = builtins.readFile ./pv.sh;
    })
  ];
}
