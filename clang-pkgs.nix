{ machine, pkgs, ... }:
let
  nixpkgs = pkgs.applyPatches {
    src = pkgs.path;
    patches = [
      (pkgs.fetchpatch {
        url = "https://github.com/NixOS/nixpkgs/commit/a4d7c395b555c2e644a2bc3108de9da6176c8fa2.patch";
        sha256 = "YeVpQSzEOymRzGfGGDEsN4obGz9tmkk2hcPJf2EPXRs=";
      })
    ];
  };
in
import nixpkgs {
  localSystem = {
    system = machine.system;
  };
  config.replaceStdenv =
    { pkgs, ... }:
    (pkgs.withCFlags [ "-O3" "-march=${machine.arch}" "-mtune=${machine.arch}" ] pkgs.clangStdenv);
}
