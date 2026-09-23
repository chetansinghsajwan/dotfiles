{
  description = "docker client (no daemon), wrapped with its config baked in";

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

      mkDocker =
        {
          pkgs,
          lib ? pkgs.lib,
          # docker's config.json content, e.g. credential helpers,
          # cliPluginsExtraDirs. Empty today - no existing customization to
          # migrate.
          settings ? { },
          extraPackages ? [ ],
        }:
        let
          configDir = pkgs.runCommand "docker-config-dir" { } ''
            mkdir -p $out
            ln -s ${pkgs.writeText "config.json" (builtins.toJSON settings)} $out/config.json
          '';
        in
        pkgs.symlinkJoin {
          # docker-client: the CLI and its compose/buildx plugins, without
          # the dockerd daemon - this repo's docker service (currently just
          # NixOS's virtualisation.docker) is a separate concern.
          name = "docker-client-wrapped";
          paths = [ pkgs.docker-client ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/docker \
              --add-flags "--config ${configDir}" \
              --suffix PATH : ${lib.makeBinPath extraPackages}

            mkdir -p $out/share/docker-shell
            cp ${./docker.sh} $out/share/docker-shell/docker.sh
            cp ${./docker.zsh} $out/share/docker-shell/docker.zsh
          '';
        };
    in
    {
      lib = { inherit mkDocker; };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkDocker { inherit pkgs; };
        }
      );
    };
}
