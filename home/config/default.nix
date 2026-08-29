{
  lib,
  overrides ? { },
}:
lib.recursiveUpdate {
  user = import ./user.nix;
  theme = import ./theme.nix;
  preferences = import ./preferences.nix;
} overrides
