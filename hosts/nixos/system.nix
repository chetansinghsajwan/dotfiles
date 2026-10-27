{ config, lib, ... }:
let
    enableGdm = config.dotfiles.system.displayManager == "gdm";
    enableSddm = config.dotfiles.system.displayManager == "sddm";
    enableHyprland = config.dotfiles.desktop.hyprland.enable;
    enableGnome = config.dotfiles.desktop.gnome.enable;
    enableKanataWatch = config.dotfiles.programs.kanata-layer-indicator.enable;
in
{
    imports = [
        ../shared/system.nix
        ../shared/locale.nix
        ../shared/kanata
    ];

    dotfiles = {
        system.isLinux = lib.mkForce true;
        system.displayManager = "sddm";
        desktop.hyprland.enable = lib.mkForce true;

        features.dev = lib.mkForce true;
        features.gui = lib.mkForce true;

        programs.docker.enable = true;
        # programs.kanata-layer-indicator.enable = true;

        theme.fonts.rawFontScale = 1.33;
    };

    boot.loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
    };

    boot.kernelModules = [ "uinput" ];
    hardware.uinput.enable = true;
    services.udev.extraRules = ''
        KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"
    ''
    # Read-only access to kanata's own virtual output device, scoped to just
    # that device (not the "input" group, which covers every physical
    # keyboard/mouse). Used by home/programs/kanata-layer-indicator.nix
    # to watch which modifiers are currently held.
    + lib.optionalString enableKanataWatch ''
        SUBSYSTEM=="input", ATTRS{name}=="kanata", GROUP="kanata-watch", MODE="0640"
    '';

    users.groups.uinput = { };
    users.groups.kanata-watch = lib.mkIf enableKanataWatch { };
    users.users = lib.mkIf enableKanataWatch (
        lib.mapAttrs (_: _: { extraGroups = [ "kanata-watch" ]; }) config.dotfiles.users
    );

    systemd.services.kanata-internalKeyboard.serviceConfig = {
        SupplementaryGroups = [
            "input"
            "uinput"
        ];
    };

    networking = {
        hostName = "nixos";
        networkmanager.enable = true;
    };

    hardware.bluetooth.enable = true;

    virtualisation.docker = {
        enable = config.dotfiles.programs.docker.enable;
        rootless = {
            enable = true;
            setSocketVariable = true;
        };
    };

    # Hyprland
    programs.hyprland.enable = enableHyprland;

    services = {
        # Gnome
        desktopManager.gnome.enable = enableGnome;

        # GDM
        displayManager.gdm.enable = enableGdm;

        # SDDM
        displayManager.sddm.enable = enableSddm;
        displayManager.sddm.wayland.enable = enableSddm;

        printing.enable = true;

        upower.enable = true;

        pulseaudio.enable = false;
        pipewire = {
            enable = true;
            alsa.enable = true;
            alsa.support32Bit = true;
            pulse.enable = true;
        };
    };

    programs.silentSDDM = {
        enable = enableSddm;
        theme = "default";
    };

    security.rtkit.enable = true;

    system.stateVersion = config.dotfiles.system.stateVersion.linux;
}
