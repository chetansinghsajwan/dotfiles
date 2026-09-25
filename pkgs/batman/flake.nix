{
  description = "batman: bat-based man page viewer";

  # Just a package plus an alias, no config to wrap.
  outputs =
    _:
    {
      homeModules.default =
        {
          config,
          pkgs,
          localLib,
          ...
        }:
        localLib.mkToggleModule config "batman" {
          home.packages = [ pkgs.bat-extras.batman ];
          home.shellAliases.bm = "batman";
        };
    };
}
