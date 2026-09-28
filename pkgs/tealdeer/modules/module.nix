# nix-wrapper-modules wrapper module: pulls in nix-wrapper-modules' own
# native tealdeer module plus this repo's customization on top - so this
# one file is the complete tealdeer wrapper, and callers only ever need
# to reference it, not also list `wrappers.wrapperModules.tealdeer`
# separately.
{ wlib, ... }:
{
  imports = [ wlib.wrapperModules.tealdeer ];

  config = {
    settings.updates.auto_update = true;
  };
}
