{
    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs";
    };

    outputs = { nixpkgs, ... }: import ./default.nix { inherit (nixpkgs) lib; };
}
