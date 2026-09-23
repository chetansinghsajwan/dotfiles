{
  description = "zsh, wrapped to set ZDOTDIR without relying on ~/.zshenv";

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

      mkZsh =
        {
          pkgs,
          lib ? pkgs.lib,
          # Path to ZDOTDIR relative to $HOME, e.g. ".config/zsh" (matches
          # home-manager's programs.zsh.dotDir). $HOME is only known at
          # runtime, so this is a --run shell snippet, not a --set value.
          zdotdirRelative ? ".config/zsh",
          extraPackages ? [ ],
        }:
        pkgs.symlinkJoin {
          name = "zsh-wrapped";
          paths = [ pkgs.zsh ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/zsh \
              --run "export ZDOTDIR=\"\$HOME/${zdotdirRelative}\"" \
              --suffix PATH : ${lib.makeBinPath extraPackages}
          '';
        };
    in
    {
      lib = { inherit mkZsh; };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkZsh { inherit pkgs; };
        }
      );
    };
}
