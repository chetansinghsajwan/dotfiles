{ config, ... }:
let
  enableGdm = config.dotfiles.system.displayManager == "gdm";
  enableSddm = config.dotfiles.system.displayManager == "sddm";
  enableHyprland = config.dotfiles.desktop.hyprland.enable;
  enableGnome = config.dotfiles.desktop.gnome.enable;
in
{
  imports = [
    ../../config
    ../shared.nix
    ../locale.nix
    ../kanata
    ../../local.nix
  ];

  dotfiles = {
    desktop.hyprland.enable = true;
    system.displayManager = "sddm";
    system.isLinux = true;
    programs.docker.enable = true;
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  boot.kernelModules = [ "uinput" ];
  hardware.uinput.enable = true;
  services.udev.extraRules = ''
    KERNEL=="uinput", MODE="0660", GROUP="uinput", OPTIONS+="static_node=uinput"
    # Read-only access to kanata's own virtual output device, scoped to just
    # that device (not the "input" group, which covers every physical
    # keyboard/mouse). Used by pkgs/kanata-layer-indicator/flake.nix
    # to watch which modifiers are currently held.
    SUBSYSTEM=="input", ATTRS{name}=="kanata", GROUP="kanata-watch", MODE="0640"
  '';

  users.groups.uinput = { };
  users.groups.kanata-watch = { };
  users.users.${config.dotfiles.user.username}.extraGroups = [ "kanata-watch" ];

  systemd.services.kanata-internalKeyboard.serviceConfig = {
    SupplementaryGroups = [
      "input"
      "uinput"
    ];
  };

  networking.networkmanager.enable = true;

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

  boot.extraModprobeConfig = ''
    options snd-intel-dspcfg dsp_driver=1
  '';

  system.stateVersion = config.dotfiles.system.stateVersion.linux;
}
