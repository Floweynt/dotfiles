args@{
    pkgs,
    lib,
    modulesPath,
    config,
    machine,
    userPackages,
    nixos-hardware,
    ...
}:
{
    imports = [
        (import "${nixos-hardware}/framework/16-inch/7040-amd")
        (import ./extern/framework-lid-workaround.nix)
    ];
    fileSystems = {
        "/" = {
            device = "/dev/disk/by-uuid/${machine.partitions.main-id}";
            fsType = "btrfs";
            options = [
                "subvol=@root"
                "noatime"
                "nodiratime"
                "discard"
                "compress=zstd"
            ];
        };
        "/nix" = {
            device = "/dev/disk/by-uuid/${machine.partitions.main-id}";
            fsType = "btrfs";
            options = [
                "subvol=@nix"
                "noatime"
                "nodiratime"
                "discard"
                "compress=zstd"
            ];
        };
        "/var/log" = {
            device = "/dev/disk/by-uuid/${machine.partitions.main-id}";
            fsType = "btrfs";
            options = [
                "subvol=@logs"
                "noatime"
                "nodiratime"
                "discard"
                "compress=zstd"
            ];
            neededForBoot = true;
        };
        "/persist" = {
            device = "/dev/disk/by-uuid/${machine.partitions.main-id}";
            fsType = "btrfs";
            options = [
                "subvol=@persist"
                "noatime"
                "nodiratime"
                "discard"
                "compress=zstd"
            ];
        };
        "/boot" = {
            device = "/dev/disk/by-uuid/${machine.partitions.boot-id}";
            fsType = "vfat";
            options = [
                "fmask=0022"
                "dmask=0022"
            ];
        };
        "/btrfs_root" = {
            device = "/dev/disk/by-uuid/${machine.partitions.main-id}";
            fsType = "btrfs";
            options = [
                "noatime"
                "nodiratime"
                "discard"
                "ro"
                "compress=zstd"
            ];
        };
    };

    networking.useDHCP = lib.mkDefault true;
    hardware = {
        graphics = {
            enable = true;
            enable32Bit = true;
        };
        bluetooth = {
            enable = true;
            powerOnBoot = false;
            settings = {
                General = {
                    Experimental = true;
                    FastConnectable = false;
                };
                Policy = {
                    AutoEnable = true;
                };
            };
        };
        framework.wakeOnInput = "lid-open";
    };

    nixpkgs.hostPlatform = {
        system = machine.system;
    };

    boot = {
        kernelParams = [
        ];
        loader.limine = {
            enable = true;
            extraConfig = ''
                /mos-rust-kernel
                    protocol: limine
                    path: boot():/limine/rkernel.elf
                    resolution: 1920x1080
                    randomize_hhdm_base: yes
                    cmdline: logging: { serial: { enable: false } }
            '';
            # additionalFiles = {
            #     "rkernel.elf" = /home/flowey/dev/utcs/cs378/common/target/x86_64-unknown-none/debug/kernel_common;
            # };
        };

        kernelPackages = pkgs.linuxPackages_6_18; /*pkgs.linuxPackages_latest; /* pkgs.linuxPackagesFor (pkgs.linux_latest.override {
            argsOverride = rec {
                src = pkgs.fetchurl {
                        url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
                        sha256 = "sha256-qtpHItuLz6C5cyhRhW1AUIK2pPouOrBnvo2xfN0RWzg=";
                };
                version = "6.19.8";
                modDirVersion = version;
            };
        });*/
        kernelModules = [ "kvm-amd" ];
        extraModulePackages = [
        ];
        supportedFilesystems = [ "btrfs" ];

        initrd = {
            compressorArgs = ["-22" "-T0" "--long" "--ultra"];
            availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usbhid" ];
            kernelModules = [ "amdgpu" ];
            luks.devices."nixos_root".device = "/dev/disk/by-uuid/${machine.partitions.main-luks-id}";
        };
    };

    hardware.enableRedistributableFirmware = true;
    hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    nix.settings.system-features = [ "gccarch-znver4" ];
}
