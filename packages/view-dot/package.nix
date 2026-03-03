{ pkgs, ... }:

pkgs.writeShellApplication {
  name = "view-dot";

  runtimeInputs = [
    pkgs.graphviz
    pkgs.librewolf
  ];

  text = builtins.readFile ./view-dot.sh;
}
