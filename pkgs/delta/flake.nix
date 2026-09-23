{
  description = "delta, wrapped with its config baked in";

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

      mkDelta =
        {
          pkgs,
          lib ? pkgs.lib,
          settings ? { },
          extraPackages ? [ ],
        }:
        let
          # delta's --config file is gitconfig-shaped (it parses out the
          # [delta] section exactly as it would from a real ~/.gitconfig),
          # so the same generator git's own config uses works here too.
          configFile = pkgs.writeText "delta.gitconfig" (lib.generators.toGitINI { delta = settings; });
        in
        pkgs.symlinkJoin {
          name = "delta-wrapped";
          paths = [ pkgs.delta ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/delta \
              --add-flags "--config ${configFile}" \
              --suffix PATH : ${lib.makeBinPath extraPackages}
          '';
        };
    in
    {
      lib = { inherit mkDelta; };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkDelta { inherit pkgs; };
        }
      );
    };
}
