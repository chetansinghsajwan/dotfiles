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

  # Gnome
  services.desktopManager.gnome.enable = enableGnome;

  # GDM
  services.displayManager.gdm.enable = enableGdm;

  # SDDM
  services.displayManager.sddm.enable = enableSddm;
  services.displayManager.sddm.wayland.enable = enableSddm;

  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  boot.extraModprobeConfig = ''
    options snd-intel-dspcfg dsp_driver=1
  '';

  networking.firewall.enable = false;

  system.stateVersion = "23.05";
}
