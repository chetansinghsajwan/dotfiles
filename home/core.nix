{ config, pkgs, ... }:
{
    home.packages = [
        pkgs.efibootmgr
    ];
}