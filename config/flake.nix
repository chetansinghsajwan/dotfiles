{
    inputs = {
        wallpapers = {
            url = "github:chetansinghsajwan/wallpapers";
            flake = false;
        };
    };

    outputs = { wallpapers, ... }: {
        modules.default = import ./options.nix { inherit wallpapers; };
    };
}
