{
    clangPkgs,
    pkgs,
    user,
    userPackages,
    ...
}:
let
    qsSysmon = clangPkgs.stdenv.mkDerivation {
        name = "qs-sysmon";
        src = ./sysmon;
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

    qsPolkit = clangPkgs.stdenv.mkDerivation {
        name = "qs-polkit";
        src = ./polkit;
        nativeBuildInputs = [
            pkgs.cmake
            clangPkgs.kdePackages.qtbase
        ];
        buildInputs = [
            clangPkgs.kdePackages.qtbase
            clangPkgs.kdePackages.qtdeclarative
        ];
        cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];
        dontWrapQtApps = true;
    };

    quickshellWrapped = pkgs.symlinkJoin {
        name = "quickshell";
        paths = [ clangPkgs.quickshell ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
            wrapProgram $out/bin/quickshell \
                --prefix PATH : ${pkgs.lib.makeBinPath [
                    pkgs.grimblast
                    pkgs.slurp
                    pkgs.grim
                    pkgs.wl-clipboard
                    pkgs.libnotify
                    pkgs.brightnessctl
                    userPackages.proxy
                ]} \
                --prefix QML_IMPORT_PATH : ${qsSysmon}/lib/qt-6/qml \
                --prefix QML_IMPORT_PATH : ${qsPolkit}/lib/qt-6/qml
        '';
    };
in
{
    users.users."${user}".packages = [
        quickshellWrapped
        clangPkgs.kdePackages.qtdeclarative
    ];

    environment.etc."quickshell/pci.ids".source = "${pkgs.hwdata}/share/hwdata/pci.ids";
    environment.etc."quickshell/usb.ids".source = "${pkgs.hwdata}/share/hwdata/usb.ids";
}
