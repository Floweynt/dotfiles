{ lib, ... }:
{
  fMap = list: fn: builtins.concatLists (builtins.map fn list);
  loadDir =
    dir: mainFileName:
    let
      programsDir = builtins.readDir dir;
      filenames = builtins.attrNames programsDir;
      isDir = f: programsDir."${f}" == "directory";
      mapper =
        f:
        if isDir f then
          {
            name = f;
            value = "${dir}/${f}/${mainFileName}.nix";
          }
        else if lib.hasSuffix ".nix" f then
          {
            name = lib.removeSuffix ".nix" f;
            value = "${dir}/${f}";
          }
        else
          null;
      entries = builtins.filter (x: x != null) (builtins.map mapper filenames);
    in
    builtins.listToAttrs entries;
}
