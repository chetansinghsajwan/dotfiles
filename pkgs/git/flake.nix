{
  description = "git, wrapped with its config baked in";

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

      mkGit =
        {
          pkgs,
          lib ? pkgs.lib,
          settings ? { },
          extraPackages ? [ ],
        }:
        let
          configFile = pkgs.writeText "gitconfig" (lib.generators.toGitINI settings);
        in
        pkgs.symlinkJoin {
          name = "git-wrapped";
          paths = [ pkgs.git ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/git \
              --set GIT_CONFIG_GLOBAL "${configFile}" \
              --suffix PATH : ${lib.makeBinPath extraPackages}

            mkdir -p $out/share/git-shell
            cp ${./git.sh} $out/share/git-shell/git.sh
            cp ${./git.zsh} $out/share/git-shell/git.zsh
          '';
        };
    in
    {
      lib = { inherit mkGit; };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkGit { inherit pkgs; };
        }
      );
    };
}
