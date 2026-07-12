{
  pkgs ? import <nixpkgs> { },
}:
pkgs.mkShell {
  buildInputs = with pkgs; [
    meson
    ninja
    cmake
    gdb
    rr
    lld
    time
    gnumake
    perf
    valgrind
  ];
  LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib/";
}
