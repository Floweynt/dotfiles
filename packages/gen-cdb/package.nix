{ pkgs, lib, ... }:
let
  path = lib.makeBinPath (
    with pkgs;
    [
      sshuttle
      iproute2
    ]
  );
in
pkgs.writers.writePython3Bin "gen-cdb" {
  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    path
  ];
} ./gen-cdb.py
