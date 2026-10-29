{
    inputs = {
        nixos-wsl.url = "path:../nixos-wsl";
    };

    outputs =
        { nixos-wsl, ... }:
        let
            sys = "x86_64-linux";
            hostname = "jman-nixos";

            module = { lib, ... }: {
                networking.hostName = lib.mkForce hostname;
                dotfiles = {
                    features = {
                        dev = lib.mkForce true;
                        gui = lib.mkForce false;
                        gaming = lib.mkForce false;
                    };
                };
            };
        in
        {
            nixosConfigurations.default = nixos-wsl.nixosConfigurations.${sys}.default.extendModules {
                modules = [ module ];
            };
        };
}
