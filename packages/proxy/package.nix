{ pkgs, lib, ... }:
let
    path = lib.makeBinPath (with pkgs; [ sshuttle iproute2 ]);
in
pkgs.writers.writePython3Bin "proxy" {
    makeWrapperArgs = [
        "--prefix" "PATH" ":" path
    ];
    flakeIgnore = [ "E302" "E225" "E501" ];
} ./proxy.py

