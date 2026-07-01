{ pkgs, lib, ... }:
let
  path = lib.makeBinPath [];
in
pkgs.writers.writePython3Bin "gen-cdb" {
  makeWrapperArgs = lib.optionals (path != "") [ "--prefix" "PATH" ":" path ];
} ./gen-cdb.py
