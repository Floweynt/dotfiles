args@{
    pkgs,
    lib,
    modulesPath,
    config,
    ...
}:
let
    home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
    
    util = import ./util.nix args;
    machine = import ./machine.nix;
    clangPkgs = pkgs;
    # clangPkgs = import ./clang-pkgs.nix (args // { inherit machine; });
    user = "flowey";
    userPackages = builtins.mapAttrs (name: value: pkgs.callPackage value {
        kernel = config.boot.kernelPackages.kernel;
        inherit util;
    }) (util.loadDir ./packages "package");
    importLocal = f: import f (args // { inherit user clangPkgs util userPackages machine; });
in
{
    imports = [
        (import "${home-manager}/nixos")
        (importLocal ./fprint.nix)
        (importLocal ./hw.nix)
        (importLocal ./persist.nix)
        (modulesPath + "/installer/scan/not-detected.nix")
    ] ++ (builtins.map importLocal (builtins.attrValues (util.loadDir ./programs "config")));

    time.timeZone = "America/Chicago";
    i18n.defaultLocale = "en_US.UTF-8";

    services = {
        printing.enable = true;
        pipewire = {
            enable = true;
            pulse.enable = true;
        };
        upower.enable = true;
        auto-cpufreq = {
            enable = true;
            settings = {
                battery = {
                    governor = "powersave";
                    turbo = "never";
                };
                charger = {
                    governor = "performance";
                    turbo = "auto";
                };
            };
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

    environment.systemPackages = with pkgs; [
        git
    ];

    fonts.packages = with pkgs; [
        nerd-fonts.jetbrains-mono
    ];

    # configure users
    users.users.flowey = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        packages = with clangPkgs; [
            nvtopPackages.amd
            clang_21
            llvmPackages_21.clang-tools
            nil
            wl-clipboard
            jetbrains.idea-community
            zip
            unzip
            prismlauncher
            python313Packages.pip
            python313
        ];
    };

    home-manager.users.flowey = {
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
