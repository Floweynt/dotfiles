{
  clangPkgs,
  pkgs,
  user,
  userPackages,
  ...
}:
let
  floweyshellPlugin = clangPkgs.stdenv.mkDerivation {
    name = "floweyshell-plugin";
    src = ./plugin;
    nativeBuildInputs = [
      pkgs.cmake
      clangPkgs.kdePackages.qtbase
    ];
    buildInputs = [
      clangPkgs.kdePackages.qtbase
      clangPkgs.kdePackages.qtdeclarative
      pkgs.liburing
    ];
    cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];
    dontWrapQtApps = true;
  };

  quickshellWrapped = pkgs.symlinkJoin {
    name = "quickshell";
    paths = [ clangPkgs.quickshell ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    meta.mainProgram = "quickshell";
    postBuild = ''
      wrapProgram $out/bin/quickshell \
          --prefix PATH : ${
            pkgs.lib.makeBinPath [
              pkgs.grimblast
              pkgs.slurp
              pkgs.grim
              pkgs.wl-clipboard
              pkgs.libnotify
              pkgs.brightnessctl
              userPackages.proxy
            ]
          } \
          --prefix QML_IMPORT_PATH : ${floweyshellPlugin}/lib/qt-6/qml
    '';
  };
in
{
  users.users."${user}".packages = [ clangPkgs.kdePackages.qtdeclarative ];

  environment.etc."quickshell/pci.ids".source = "${pkgs.hwdata}/share/hwdata/pci.ids";
  environment.etc."quickshell/usb.ids".source = "${pkgs.hwdata}/share/hwdata/usb.ids";

  home-manager.users."${user}".programs.quickshell = {
    enable = true;
    package = quickshellWrapped;
    configs.floweyshell = ./src;
    activeConfig = "floweyshell";
    systemd.enable = true;
  };
}
