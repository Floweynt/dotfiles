{ lib }:
let
  recordDir = ../lock/mods/modrinth;
  slugs = lib.pipe (builtins.readDir recordDir) [
    (lib.filterAttrs (_: type: type == "regular"))
    builtins.attrNames
    (map (lib.removeSuffix ".json"))
  ];
  readMod = slug: builtins.fromJSON (builtins.readFile (recordDir + "/${slug}.json"));
in
{
  fabric.modrinth = lib.genAttrs slugs readMod;
}
