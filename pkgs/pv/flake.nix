{
  description = "pv (preview): dispatches a file to the right terminal renderer";

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

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkPv { inherit pkgs; };
        }
      );
    };
}
