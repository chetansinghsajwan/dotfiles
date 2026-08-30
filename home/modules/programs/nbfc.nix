{ pkgs, ... }:
let
  nbfc-linux = import (
    pkgs.fetchFromGitHub {
      owner = "nbfc-linux";
      repo = "nbfc-linux";
      rev = "0.1.15";
      sha256 = "sha256-+xYr2uIxfMaMAaHGvvA+0WPZjwj3wVAc34e1DWsJLqE=";
    }
  );
  command = "bin/nbfc_service --config-file '/home/${config.dotfiles.user.username}/.config/nbfc.json'";
in
{
  home.packages = [ nbfc-linux ];

  systemd.user.services.nbfc_service = {
    Unit = {
      Description = "NoteBook FanControl service";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = {
      ExecStart = "${nbfc-linux.packages.${pkgs.system}.nbfc}/${command}";
    };
  };
}
