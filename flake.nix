{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/9154f4569b6cdfd3c595851a6ba51bfaa472d9f3";
    nix-jetbrains-plugins.url = "github:nix-community/nix-jetbrains-plugins";
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nixos-hardware,
      nix-jetbrains-plugins,
      ...
    }:
    let
      lib = nixpkgs.lib;
      hwDir = builtins.readDir ./hw;
      hwNames = builtins.filter (n: lib.hasSuffix ".nix" n) (builtins.attrNames hwDir);
      hwList = map (n: import ./hw/${n}) hwNames;
      mkSystem =
        hw:
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit nixos-hardware nix-jetbrains-plugins;
            machine = hw.machine;
          };
          modules = [
            home-manager.nixosModules.home-manager
            hw.nixosModule
            ./hw.nix
            ./configuration.nix
          ];
        };
    in
    {
      nixosConfigurations = builtins.listToAttrs (
        map (hw: {
          name = hw.machine.hostname;
          value = mkSystem hw;
        }) hwList
      );
    };
}
