{
    config,
    lib,
    pkgs,
    ...
}: let
    cfg = config.dotfiles;
    isLinux = cfg.system.isLinux;
    isDarwin = cfg.system.isDarwin;
in {
    users.users = lib.mapAttrs (
        _name: u:
            {
                home =
                    if isDarwin
                    then "/Users/${u.homeDir}"
                    else "/home/${u.homeDir}";
                shell = pkgs.${cfg.shell.program};
            }
            // lib.optionalAttrs isLinux {
                isNormalUser = true;
                inherit (u) extraGroups;
            }
    )
    cfg.users;

    programs =
        {
            ${cfg.shell.program}.enable = true;
        }
        // lib.optionalAttrs isLinux {
            nix-ld.enable = true;
        };

    nix.settings.experimental-features = [
        "nix-command"
        "flakes"
    ];

    # The binary cache of the tuikit tools and the helix fork (see the flake's nixConfig, which
    # covers nix-darwin). Trusted here so a rebuild never prompts.
    nix.settings.extra-substituters = lib.mkIf isLinux ["https://chetansinghsajwan-dotfiles.cachix.org"];
    nix.settings.extra-trusted-public-keys = lib.mkIf isLinux ["chetansinghsajwan-dotfiles.cachix.org-1:HO86Y5cJ6dyBFTk9gbReVExpL04xLktn4OYHJmPX0tI="];

    # nix-darwin manages the Nix install itself, so leave nix.* unmanaged there.
    nix.enable = isLinux;
    nix.optimise.automatic = isLinux;
    nixpkgs.config.allowUnfree = true;

    networking = lib.optionalAttrs isLinux {
        firewall.enable = true;
    };
}
