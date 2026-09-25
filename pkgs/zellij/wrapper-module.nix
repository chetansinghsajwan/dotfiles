# nix-wrapper-modules doesn't ship a native zellij wrapper module, so this
# is the generic mechanism a native one would provide: raw KDL text for
# config.kdl and named layouts, pointed at via ZELLIJ_CONFIG_DIR.
{
  config,
  lib,
  pkgs,
  wlib,
  ...
}:
{
  imports = [ wlib.modules.default ];

  options.configKdl = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = "Raw KDL content for zellij's config.kdl.";
  };

  options.layouts = lib.mkOption {
    type = lib.types.attrsOf lib.types.lines;
    default = { };
    description = "Named layouts, written to layouts/<name>.kdl as raw KDL.";
  };

  config = {
    package = lib.mkDefault pkgs.zellij;

    env.ZELLIJ_CONFIG_DIR = "${placeholder config.outputName}/zellij-config";

    constructFiles = {
      config = {
        relPath = "zellij-config/config.kdl";
        content = config.configKdl;
      };
    }
    // lib.mapAttrs' (
      name: text:
      lib.nameValuePair "layout_${name}" {
        relPath = "zellij-config/layouts/${name}.kdl";
        content = text;
      }
    ) config.layouts;
  };
}
