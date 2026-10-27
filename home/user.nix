{ config, lib, ... }:
{
    options.dotfiles.currentUser = lib.mkOption {
        type = lib.types.raw;
        readOnly = true;
        description = "The dotfiles.users entry for the user this profile is built for.";
    };
}
