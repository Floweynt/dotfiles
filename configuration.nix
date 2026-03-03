args@{
    pkgs,
    lib,
    config,
    ...
}:
let
    home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
    nixos-hardware = builtins.fetchGit { 
        url = "https://github.com/NixOS/nixos-hardware.git";
        rev = "9154f4569b6cdfd3c595851a6ba51bfaa472d9f3";
    };
    util = import ./util.nix args;
    machine = import ./machine.nix;
    clangPkgs = pkgs;
    # clangPkgs = import ./clang-pkgs.nix (args // { inherit machine; });
    user = "flowey";
    userPackages = builtins.mapAttrs (name: value: pkgs.callPackage value {
        kernel = config.boot.kernelPackages.kernel;
        inherit util;
    }) (util.loadDir ./packages "package");
    importLocal = f: import f (args // { inherit user clangPkgs util userPackages machine nixos-hardware; });
in
{
    imports = [
        (import "${home-manager}/nixos")
        (importLocal ./fprint.nix)
        (importLocal ./hw.nix)
        (importLocal ./persist.nix)
        (importLocal ./power.nix)
    ] ++ (builtins.map importLocal (builtins.attrValues (util.loadDir ./programs "config")));

    time.timeZone = "America/Chicago";
    i18n.defaultLocale = "en_US.UTF-8";

    nix.extraOptions = ''
    experimental-features = nix-command
    '';

    programs.ccache.enable = true;

    services = {
        printing.enable = true;
        pipewire = {
            enable = true;
            pulse.enable = true;
        };
    };

    networking = {
        hostName = "nix-fw16";
        networkmanager = {
            enable = true;
            # insertNameservers = [ "1.1.1.1" "8.8.8.8" ];
            wifi.powersave = true;
            plugins = lib.mkForce [ ];
            logLevel = "INFO";
        };
    };

    security = {
        polkit.enable = true;
    };

    # TODO: fixme
    environment.etc."libinput/local-overrides.quirks".text = ''
      [Never Debounce]
      MatchUdevType=mouse
      ModelBouncingKeys=1
    '';

    environment.systemPackages = with pkgs; [
        git
    ];

    fonts.packages = with pkgs; [
        nerd-fonts.jetbrains-mono
    ];

    # configure users
    users = {
        mutableUsers = false;
        allowNoPasswordLogin = true;
        users.umbresp = {
            isNormalUser = true;
            home = "/home/umbresp";
            hashedPassword = "$6$/rW1QoGX3Q5pcZoy$KZvak.Mvyu.IqkkoAONRMg08pB12bSexcC/4wi2wEHWNoWXq0aEX28BqxEeIKg3.lCJ8OWYliBYOInhvN.ju41";
            uid = 1001;
        };
        users."${user}" = {
            isNormalUser = true;
            home = "/home/${user}";
            uid = 1000;
            extraGroups = [ "wheel" ];
            packages = with clangPkgs; [
                nvtopPackages.amd
                wl-clipboard
                jetbrains.idea-oss
                zip
                unzip
                prismlauncher
                python313Packages.pip
                python313
                ffmpeg_6-full
                userPackages.proxy
                userPackages.view-dot
                userPackages.gen-cdb
                clang_22
                llvmPackages_22.clang-tools
                ccache
            ];
        };
    };

    home-manager.users."${user}" = {
        programs = {
            librewolf = {
                enable = true;
                package = clangPkgs.librewolf;
                settings = {
                    "apz.gtk.kinetic_scroll.enabled" = false;
                    "places.history.enabled" = false;
                    "privacy.resistFingerprinting.letterboxing" = true;
                    "signon.rememberSignons" = true;
                    "layout.css.devPixelsPerPx" = "1.3";
                };
            };
            btop = {
                enable = true;
                package = clangPkgs.btop;
                settings = {
                };
            };
            fastfetch = {
                enable = true;
                package = clangPkgs.fastfetch;
            };
            rofi.enable = true;
            bat = {
                enable = true;
                package = clangPkgs.bat;
            };
        };
        
        home = {
            stateVersion = "25.05";
        };
    };

    # don't change this
    system.stateVersion = "25.05";
}
