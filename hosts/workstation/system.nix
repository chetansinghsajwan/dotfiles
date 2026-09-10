{ config, pkgs, ... }:
let
  enableGdm = config.dotfiles.system.displayManager == "gdm";
  enableSddm = config.dotfiles.system.displayManager == "sddm";
in
{
  programs.hyprland.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.flatpak.enable = true;

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

  time.timeZone = "Asia/Kolkata";
  i18n.defaultLocale = "en_IN";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_IN";
    LC_IDENTIFICATION = "en_IN";
    LC_MEASUREMENT = "en_IN";
    LC_MONETARY = "en_IN";
    LC_NAME = "en_IN";
    LC_NUMERIC = "en_IN";
    LC_PAPER = "en_IN";
    LC_TELEPHONE = "en_IN";
    LC_TIME = "en_IN";
  };

  virtualisation.docker = {
    enable = true;
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };

  services.xserver.enable = true;

  # GDM
  services.displayManager.gdm.enable = enableGdm;
  services.desktopManager.gnome.enable = enableGdm;
  services.gnome.core-apps.enable = false;

  # SDDM
  services.displayManager.sddm.enable = enableSddm;
  services.displayManager.sddm.wayland.enable = enableSddm;

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

  programs.kdeconnect = {
    enable = true;
    package = pkgs.gnomeExtensions.gsconnect;
  };

  networking.firewall.enable = false;

  system.stateVersion = "23.05";
}
