_: {
    services.kanata = {
        enable = true;
        # port is read by pkgs/kb (its default kanata address) to
        # follow layer changes over kanata's TCP server; keep the two in sync.
        keyboards.main = {
            configFile = ./kanata.kbd;
            port = 6666;
        };
    };
}
