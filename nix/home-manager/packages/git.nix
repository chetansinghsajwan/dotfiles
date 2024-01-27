{ config, pkgs, ... }:
{
    home.packages = [
        pkgs.git
    ];

    programs.git = {
        enable = true;
        userName = "shifu-dev";
        userEmail = "csingh8476@gmail.com";

        extraConfig = {
            core.editor = "nvim";
            credential.helper = "store";

            advice.pushUpdateRejected = false;
            advice.pushNonFFCurrent = false;
            advice.pushNonFFMatching = false;
            advice.pushAlreadyExists = false;
            advice.pushFetchFirst = false;
            advice.pushNeedsForce = false;
            advice.statusHints = false;
            advice.statusUoption = false;
            advice.commitBeforeMerge = false;
            advice.resolveConflict = false;
            advice.implicitIdentity = false;
            advice.detachedHead = false;
            advice.amWorkDir = false;
            advice.rmHints = false;
        };
    };
}
