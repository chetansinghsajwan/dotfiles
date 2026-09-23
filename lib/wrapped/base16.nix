# Shared helper for the wrapped-package flakes under pkgs/ (helix, btop,
# zellij, yazi) that render a static theme template with base16 colors
# substituted in.
_:
{
  # Substitute "@key@" placeholders in a template string with values from
  # a flat attrset, e.g. { base00 = "#hex"; syntectTheme = "/nix/store/..."; }.
  # Not limited to base16 names - any placeholder in the template that has
  # a matching attrset key gets substituted.
  substituteTemplate =
    template: replacements:
    builtins.replaceStrings (map (name: "@${name}@") (
      builtins.attrNames replacements
    )) (builtins.attrValues replacements) template;
}
