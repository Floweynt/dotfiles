{
  pkgs,
  lib,
  rules,
}:
{
  libraries,
  client,
  os,
  arch,
  features,
}:
let
  fetchLib =
    l:
    pkgs.fetchurl {
      inherit (l) url hash;
    };

  allowed =
    l:
    rules.evalRules {
      rules = l.rules or null;
      inherit os arch features;
    };

  classpathLibs = builtins.filter (l: !l.native && allowed l) libraries;
  nativeLibs = builtins.filter (l: l.native && allowed l && rules.nativeMatches l os arch) libraries;

  clientJar = pkgs.fetchurl client;
  classpathList = [ "${clientJar}" ] ++ map (l: "${fetchLib l}") classpathLibs;

  nativesDir = pkgs.runCommand "mc-natives" { nativeBuildInputs = [ pkgs.unzip ]; } ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n" (
      l:
      let
        exclude = lib.concatMapStringsSep " " (e: "-x '${e}*'") (l.exclude or [ ]);
      in
      "unzip -o -q ${fetchLib l} -d $out ${exclude} || true"
    ) nativeLibs}
  '';
in
{
  inherit classpathList nativesDir;
}
