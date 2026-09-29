{ llib, ... }:
{
  programs.vscode = {
    mutableExtensionsDir = false;
    profiles.default = {
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;
    };
  };

  imports =
    llib.importDir ./modules
    ++ llib.importDir ./languages
    ++ llib.importDir ./themes
    ++ llib.importDir ./features;
}
