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
    ./hardware.nix
    ../../local.nix
  ];

  dotfiles = {
    desktop.hyprland.enable = true;
    system.displayManager = "gdm";
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
  '';

  users.groups.uinput = { };

  systemd.services.kanata-internalKeyboard.serviceConfig = {
    SupplementaryGroups = [
      "input"
      "uinput"
    ];
  };

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

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

    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };

  security.rtkit.enable = true;

  boot.extraModprobeConfig = ''
    options snd-intel-dspcfg dsp_driver=1
  '';

  system.stateVersion = "23.05";
}
