{
  pkgs,
  lib,
  version,
  loaderVersion,
  loaderName,
  vanillaMainClass,
  mods ? [ ],
}:
let
  loaders = builtins.fromJSON (builtins.readFile ../../lock/fabric/loaders.json);
  resolved =
    if loaderVersion == null || loaderVersion == "latest" then loaders.latest else loaderVersion;

  loaderLock = builtins.fromJSON (builtins.readFile (../../lock/fabric/loader + "/${resolved}.json"));
  intermediary = builtins.fromJSON (
    builtins.readFile (../../lock/fabric/intermediary + "/${version}.json")
  );

  target = "${version}+${loaderName}";
  readMod = slug: builtins.fromJSON (builtins.readFile (../../lock/mods/modrinth + "/${slug}.json"));

  closure = builtins.genericClosure {
    startSet = map (r: { key = r.slug; record = r; }) mods;
    operator =
      { key, record }:
      let
        vid = builtins.head (
          record.byTarget.${target} or (throw "minecraft-nix: mod ${record.slug} has no ${target} build")
        );
        deps = builtins.filter (d: d.type == "required") (record.versions.${vid}.dependencies or [ ]);
      in
      map (d: { key = d.slug; record = readMod d.slug; }) deps;
  };

  modJars = map (
    { record, ... }:
    let
      vid = builtins.head record.byTarget.${target};
      v = record.versions.${vid};
    in
    pkgs.fetchurl { inherit (v) url hash; }
  ) closure;

  addModsArg = lib.optional (mods != [ ]) "-Dfabric.addMods=${lib.concatMapStringsSep ":" (j: "${j}") modJars}";
in
{
  libraries = [ intermediary ] ++ loaderLock.libraries;
  mainClass = loaderLock.mainClass;
  # tells fabric loader the emulated vanilla entrypoint (tooling looks for it)
  jvmArgs = [ "-DFabricMcEmu= ${vanillaMainClass} " ] ++ addModsArg;
}
