{
  description = "libreoffice: office suite";

  # No nix-wrapper-modules here: nothing to wrap, just a package install.
  outputs = _: {
    homeModules.default =
      {
        config,
        pkgs,
        localLib,
        ...
      }:
      localLib.mkToggleModule config "libreoffice" {
        home.packages = [ pkgs.libreoffice ];
      };
  };
}
