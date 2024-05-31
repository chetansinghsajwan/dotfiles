{ config, inputs, pkgs, ... }:
let
  nbfc_pkg = inputs.nbfc-linux.packages.x86_64-linux.default;
  command = "bin/nbfc_service --read-only --config-file /home/chetan/dotfiles/hosts/workstation/nbfc.json";
in
{
  environment.systemPackages = [
    nbfc_pkg
  ];

  systemd.services.nbfc_service = {
    enable = true;
    description = "NoteBook FanControl service";
    serviceConfig.Type = "simple";
    path = [ pkgs.kmod ];
    script = "${nbfc_pkg}/${command}";
    wantedBy = [ "multi-user.target" ];
  };
}
