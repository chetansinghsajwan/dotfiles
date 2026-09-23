{
  description = "eza, wrapped with its default flags baked in";

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

      # This repo's own eza customization, baked in as the default.
      defaultSettings = {
        git = true;
        icons = "always";
      };

      mkEza =
        {
          pkgs,
          lib ? pkgs.lib,
          # eza's flags as an attrset, e.g. { git = true; icons = "always"; },
          # merged over defaultSettings above. No config-file format exists
          # for eza beyond EZA_CONFIG_DIR's theme.yml (colors only, unused
          # here - eza has no existing stylix target/theme to migrate), so
          # this is flags-only.
          settings ? { },
          extraPackages ? [ ],
          # localLib.wrapped.cliFlags.render - see pkgs/fzf/flake.nix for
          # the same parameter.
          renderCliFlags ? (
            settings:
            lib.concatStringsSep " " (
              lib.flatten (
                lib.mapAttrsToList (
                  name: value:
                  if builtins.isList value then
                    map (v: "--${name} ${toString v}") value
                  else if builtins.isBool value then
                    lib.optional value "--${name}"
                  else
                    "--${name} ${toString value}"
                ) settings
              )
            )
          ),
        }:
        pkgs.symlinkJoin {
          name = "eza-wrapped";
          paths = [ pkgs.eza ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/eza \
              --add-flags ${lib.escapeShellArg (renderCliFlags (lib.recursiveUpdate defaultSettings settings))} \
              --suffix PATH : ${lib.makeBinPath extraPackages}
          '';
        };
    in
    {
      lib = { inherit mkEza; };

      packages = forEachSystem (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = mkEza { inherit pkgs; };
        }
      );
    };
}
