{
  description = "Declarative vanilla Minecraft instances via Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      rust-overlay,
      flake-utils,
      ...
    }:
    {
      lib.mkInstance =
        pkgs:
        import ./nix/instance.nix {
          inherit pkgs;
          inherit (pkgs) lib;
          tools = import ./nix/tools.nix {
            inherit pkgs;
            inherit (pkgs) lib;
          };
        };

      overlays.default = final: _prev: {
        minecraft-tools = import ./nix/tools.nix {
          pkgs = final;
          inherit (final) lib;
        };
        minecraft = import ./nix/versions.nix {
          pkgs = final;
          inherit (final) lib;
        };
      };

      nixosModules.default = import ./nix/nixos-module.nix self.lib.mkInstance;
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        inherit (pkgs) lib;
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };
        rustToolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
        tools = import ./nix/tools.nix { inherit pkgs lib; };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            rustToolchain
            pkgs.pkg-config
            pkgs.gdb
          ];
        };

        packages = {
          inherit tools;
        };

        legacyPackages.minecraft = import ./nix/versions.nix { inherit pkgs lib; };

        apps = {
          default = {
            type = "app";
            program = lib.getExe' tools "mc";
          };
          update-lock = {
            type = "app";
            program = lib.getExe' tools "mc-lock-gen";
          };
        };
      }
    );
}
