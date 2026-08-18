{ ... }:
{
  programs.vscode = {
    userSettings = {
      "json.format.enable" = true;
      "json.format.keepLines" = false;
      "json.maxItemsComputed" = 5000;
      "json.schemaDownload.enable" = true;
      "json.schemas" = [ ];
      "json.trace.server" = "off";
      "json.validate.enable" = true;
    };
  };
}
