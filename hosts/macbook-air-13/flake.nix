{
    inputs = {
        darwin.url = "path:../darwin";
    };

    outputs = { darwin, ... }:
    let
        sys = "aarch64-darwin";
    in {
        darwinConfigurations.default = darwin.darwinConfigurations.${sys}.default;
    };
}
