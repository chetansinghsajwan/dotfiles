{ config, lib, ... }:
{
    imports = [
        ../shared/system.nix
    ];

    dotfiles.system.isDarwin = lib.mkForce true;
    system.stateVersion = config.dotfiles.system.stateVersion.darwin;
}
