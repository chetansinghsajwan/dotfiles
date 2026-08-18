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
    user = "chetan";
    command = "bin/nbfc_service --config-file '/home/${user}/.config/nbfc.json'";
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

