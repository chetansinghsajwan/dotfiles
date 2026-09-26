{
  description = "dconf-editor: GSettings/dconf database editor";

  # No nix-wrapper-modules here: nothing to wrap, just a package install plus
  # a dconf setting.
  outputs = _: {
    homeModules.default =
      {
        config,
        pkgs,
        localLib,
        ...
      }:
      localLib.mkToggleModule config "dconf-editor" {
        home.packages = with pkgs; [
          dconf-editor
        ];

        dconf.settings."ca/desrt/dconf-editor" = {
          "show-warning" = false;
        };
      };
  };
}
