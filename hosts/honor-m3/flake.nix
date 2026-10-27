{
    inputs = {
        nixos.url = "path:../nixos";
    };

    outputs =
        { nixos, ... }:
        let
            sys = "x86_64-linux";

            extendNixosConfig =
                _name: cfg:
                cfg.extendModules {
                    modules = [ ./system.nix ];
                };
        in
        {
            nixosConfigurations = builtins.mapAttrs extendNixosConfig nixos.nixosConfigurations.${sys};
        };
}
