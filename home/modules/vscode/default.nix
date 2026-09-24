{ localLib, ... }:
{
  programs.vscode = {
    mutableExtensionsDir = false;
    profiles.default = {
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;
    };
  };

  imports =
    localLib.importDir ./modules
    ++ localLib.importDir ./languages
    ++ localLib.importDir ./themes
    ++ localLib.importDir ./features;
}
