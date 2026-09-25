{
  description = "pv (preview): dispatches a file to the right terminal renderer";

  # A self-contained script, not a third-party program with config to
  # wrap - no nix-wrapper-modules needed here, unlike most of the other
  # pkgs/<name>/ flakes.
  outputs =
    _:
    let
      mkPv =
        {
          pkgs,
          extraPackages ? [ ],
        }:
        pkgs.writeShellApplication {
          name = "pv";
          runtimeInputs =
            with pkgs;
            [
              file
              bat
              tidy-viewer
            ]
            ++ extraPackages;
          text = builtins.readFile ./pv.sh;
        };
    in
    {
      lib = { inherit mkPv; };

      # `pv` (preview): dispatches a file to the right terminal renderer -
      # column-aligned tidy-viewer for CSV/TSV, syntax-highlighted bat for
      # everything else bat can read, "unsupported" otherwise. Installed as
      # a plain PATH binary (not a shell function) so it works identically
      # from an interactive shell and from yazi's `piper`, which spawns a
      # bare `sh -c` with no rc sourcing and so can't see shell functions.
      homeModules.default =
        { pkgs, ... }:
        {
          config.home.packages = [ (mkPv { inherit pkgs; }) ];
        };
    };
}
