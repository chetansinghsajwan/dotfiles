{ config, lib, ... }:
{
    imports = [
        ../shared.nix
        ../locale.nix
    ];

    dotfiles = {
        system.isWsl = lib.mkForce true;
        system.isLinux = lib.mkForce true;
        features.gui = lib.mkForce false;
    };

    wsl.enable = true;
    wsl.defaultUser = config.dotfiles.user.username;

    networking.hostName = "nixos-wsl";
    system.stateVersion = config.dotfiles.system.stateVersion.linux;
}
