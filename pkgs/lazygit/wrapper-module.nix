# nix-wrapper-modules doesn't ship a native lazygit wrapper module (unlike
# yazi/helix/btop/git/...), so this is the generic mechanism a native one
# would provide: a `settings` option rendered to lazygit's config.yml, and
# `package` defaulted to pkgs.lazygit. Repo-specific config lives in
# module.nix instead, mirroring how the native modules split.
{
  config,
  lib,
  pkgs,
  wlib,
  ...
}:
{
  imports = [ wlib.modules.default ];

  options.settings = lib.mkOption {
    default = { };
    description = ''
      Content of lazygit's config.yml file.
      See <https://github.com/jesseduffield/lazygit/blob/master/docs/Config.md>
    '';
    type = lib.types.submodule {
      freeformType = (pkgs.formats.json { }).type;
    };
  };

  config.package = lib.mkDefault pkgs.lazygit;

  # lazygit's config format is YAML, but valid JSON is valid YAML, so
  # `builtins.toJSON` is a complete config.yml serializer here - no
  # separate YAML converter (unlike yazi's TOML output) is needed.
  config.constructFiles.config = {
    relPath = "config.yml";
    content = builtins.toJSON config.settings;
  };

  # LG_CONFIG_FILE (a comma-separated list of paths) overrides lazygit's
  # default XDG config lookup - the same role YAZI_CONFIG_HOME plays for yazi.
  config.env.LG_CONFIG_FILE = config.constructFiles.config.path;
}
