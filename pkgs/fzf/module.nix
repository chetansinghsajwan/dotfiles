# nix-wrapper-modules doesn't ship a native fzf wrapper module, so this
# bakes this repo's own fzf customization (popup layout, binds, and -
# via `colorArgs`, filled in externally from Stylix colors - the theme)
# directly into the wrapped binary's FZF_DEFAULT_OPTS.
{
  config,
  lib,
  pkgs,
  wlib,
  ...
}:
{
  imports = [ wlib.modules.default ];

  options.colorArgs = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    description = ''
      Value for fzf's --color flag (comma-separated key:value pairs).
      Set externally, since a plain wrapper module only ever sees its
      own submodule config, not the config of whatever imports it.
    '';
  };

  config = {
    package = lib.mkDefault pkgs.fzf;

    env.FZF_DEFAULT_OPTS = lib.concatStringsSep " " (
      [
        "--popup 90%"
        "--border rounded"
        "--layout reverse"
        "--margin 1"
        "--padding 1"
        "--preview-window right:60%:noborder"
        "--bind ctrl-a:select-all"
        "--bind alt-k:preview-half-page-up"
        "--bind alt-j:preview-half-page-down"
        "--bind ctrl-/:toggle-preview"
      ]
      ++ lib.optional (config.colorArgs != null) "--color ${config.colorArgs}"
    );
  };
}
