{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/9154f4569b6cdfd3c595851a6ba51bfaa472d9f3";
  };

  outputs = { self, nixpkgs, home-manager, nixos-hardware, ... }:
  let
    machine = import ./machine.nix;
  in {
    nixosConfigurations.nix-fw16 = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit nixos-hardware machine; };
      modules = [
        home-manager.nixosModules.home-manager
        ./configuration.nix
      ];
    };
  };
}
