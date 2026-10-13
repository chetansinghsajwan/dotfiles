{ config, lib, ... }:
{
    imports = [
        ../shared.nix
    ];

    dotfiles.system.isDarwin = lib.mkForce true;
    system.stateVersion = config.dotfiles.system.stateVersion.darwin;
}
