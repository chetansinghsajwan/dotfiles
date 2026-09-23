{
  config,
  pkgs,
  lib,
  docker-wrapped,
  ...
}:
let
  dockerPkg = docker-wrapped.lib.mkDocker { inherit pkgs lib; };
in
{
  config = lib.mkIf config.dotfiles.programs.docker.enable {
    home.packages = [ dockerPkg ];

    programs.bash.initExtra = "source ${dockerPkg}/share/docker-shell/docker.sh";
    # docker.zsh (ZLE widgets/bindkey) is zsh-only, so it isn't sourced into bash.
    programs.zsh.initContent = ''
      source ${dockerPkg}/share/docker-shell/docker.sh
      source ${dockerPkg}/share/docker-shell/docker.zsh
    '';
  };
}
