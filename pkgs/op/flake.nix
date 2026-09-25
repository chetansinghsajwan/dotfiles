{
  description = "op (open): dispatches a file to the right interactive tool";

  # A self-contained script, not a third-party program with config to
  # wrap - no nix-wrapper-modules needed here, unlike most of the other
  # pkgs/<name>/ flakes.
  outputs =
    _:
    let
      mkOp =
        {
          pkgs,
          extraPackages ? [ ],
        }:
        pkgs.writeShellApplication {
          name = "op";
          # No editor listed here on purpose: op.sh falls back to the bare
          # "hx" command only when $EDITOR is unset, and this repo always
          # sets $EDITOR - listing a plain pkgs.helix would put an
          # unthemed/unconfigured hx ahead of the real (wrapped) one on
          # PATH for that lookup.
          runtimeInputs =
            with pkgs;
            [
              file
              csvlens
            ]
            ++ extraPackages;
          text = builtins.readFile ./op.sh;
        };
    in
    {
      lib = { inherit mkOp; };

      # `op` (open): dispatches a file to the right interactive tool - csvlens
      # for CSV/TSV, $EDITOR (falling back to hx) for everything else `file`
      # calls text, "unsupported" otherwise. Installed as a plain PATH binary
      # (not a shell function) so it works identically from an interactive
      # shell and from yazi, mirroring how `pv` previews the same file types.
      homeModules.default =
        { pkgs, ... }:
        {
          config.home.packages = [ (mkOp { inherit pkgs; }) ];
        };
    };
}
