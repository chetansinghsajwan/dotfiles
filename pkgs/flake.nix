{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    yazi = {
      url = "path:./yazi";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, yazi, ... }: {
    inherit yazi;
  };
}
