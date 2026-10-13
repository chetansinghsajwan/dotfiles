{ lib, ... }: {
    networking.hostName = lib.mkForce "honor-m3-nixos";

    boot.extraModprobeConfig = ''
        options snd-intel-dspcfg dsp_driver=1
    '';
}
