{ config, lib, ... }:
{
    imports = [
        ../shared/system.nix
        ../shared/kanata/darwin.nix
    ];

    dotfiles.system.isDarwin = lib.mkForce true;
    system.stateVersion = config.dotfiles.system.stateVersion.darwin;
}
