let
  user = import ./user.nix;
  theme = import ./theme.nix;
  preferences = import ./preferences.nix;
in
{
  inherit user theme preferences;
}
