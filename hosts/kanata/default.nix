_: {
  services.kanata = {
    enable = true;
    # port is read by pkgs/kanata-layer-indicator/flake.nix to
    # watch for layer changes over kanata's TCP server; keep the two in sync.
    keyboards.main = {
      configFile = ./kanata.kbd;
      port = 6666;
    };
  };
}
