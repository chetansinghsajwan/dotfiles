_: {
  services.kanata = {
    enable = true;
    # port is read by home/modules/programs/kanata-notify.nix to watch for
    # layer changes over kanata's TCP server; keep the two in sync.
    keyboards.main = {
      configFile = ./kanata.kbd;
      port = 6666;
    };
  };
}
