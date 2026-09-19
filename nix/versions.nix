{ pkgs, lib }:
let
  mkInstance = import ./instance.nix {
    inherit pkgs lib;
    tools = import ./tools.nix { inherit pkgs lib; };
  };
  versions = map (lib.removeSuffix ".json") (builtins.attrNames (builtins.readDir ../lock/versions));
in
lib.genAttrs versions (v: mkInstance { version = v; }) // {
  mods = import ./mods.nix { inherit lib; };
}
