{
  description = "tealdeer, wrapped with its config baked in";

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

      mkTealdeer =
        {
          pkgs,
          lib ? pkgs.lib,
          settings ? { },
          extraPackages ? [ ],
        }:
        let
          tomlFormat = pkgs.formats.toml { };
          configFile = tomlFormat.generate "tealdeer.toml" settings;
        in
        pkgs.symlinkJoin {
          name = "tealdeer-wrapped";
          paths = [ pkgs.tealdeer ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/tldr \
              --add-flags "--config-path ${configFile}" \
              --suffix PATH : ${lib.makeBinPath extraPackages}
          '';
        };
    in
    {
      lib = { inherit mkTealdeer; };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkTealdeer { inherit pkgs; };
        }
      );
    };
}
