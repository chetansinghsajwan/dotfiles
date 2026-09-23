{
  description = "op (open): dispatches a file to the right interactive tool";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      forEachSystem =
        f:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ] f;

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

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkOp { inherit pkgs; };
        }
      );
    };
}
