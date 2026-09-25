# This repo's own btop customization. Theming is set separately by
# whatever imports this (see flake.nix's `homeModules.default`), since it
# needs the outer config's `colors` - a plain wrapper module like this one
# only ever sees its own submodule config, not the config around it.
{
  config = {
    settings = {
      vim_keys = true;
      theme_background = false;
    };
  };
}
