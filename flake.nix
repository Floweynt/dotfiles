{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-jetbrains-plugins = {
      url = "github:nix-community/nix-jetbrains-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    fstar = {
      url = "github:FStarLang/FStar";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      nixos-hardware,
      nix-jetbrains-plugins,
      fstar,
      ...
    }:
    let
      lib = nixpkgs.lib;
      util = import ./util.nix { inherit lib; };
      hwDir = builtins.readDir ./hw;
      hwNames = builtins.filter (n: lib.hasSuffix ".nix" n) (builtins.attrNames hwDir);
      hwList = map (n: import ./hw/${n}) hwNames;
      systems = lib.unique (map (hw: hw.machine.system) hwList);
      mkSystem =
        hw:
        nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit self nixos-hardware nix-jetbrains-plugins;
            machine = hw.machine;
          };
          modules = [
            {
              nixpkgs.overlays = [
                (final: prev: {
                  fstar = fstar.packages.${final.system}.fstar;
                })
              ];
            }
            home-manager.nixosModules.home-manager
            hw.nixosModule
            ./hw.nix
            ./configuration.nix
          ];
        };
      mkPackages =
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          all = builtins.mapAttrs (name: value: pkgs.callPackage value { inherit util; }) (
            util.loadDir ./packages "package"
          );
        in
        lib.filterAttrs (_: lib.isDerivation) all;
    in
    {
      packages = lib.genAttrs systems mkPackages;

      nixosConfigurations = builtins.listToAttrs (
        map (hw: {
          name = hw.machine.hostname;
          value = mkSystem hw;
        }) hwList
      );

      devShells = lib.genAttrs systems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in

        {
          llvm = pkgs.mkShell {
            packages = with pkgs; [
              clang
              clang-tools
              lld
              cmake
              ninja
              ccache
              python3
              libxml2
              zlib
              zstd
            ];

            shellHook = ''
              export LD_LIBRARY_PATH="${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.zlib}/lib:${lib.getLib pkgs.zstd}/lib:$LD_LIBRARY_PATH"
            '';
          };
        }
      );
    };
}
