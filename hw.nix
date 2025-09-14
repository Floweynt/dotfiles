args@{
    pkgs,
    lib,
    modulesPath,
    config,
    machine,
    userPackages,
    ...
}:
let 
    amdgpu-stability-patch = pkgs.fetchpatch {
        name = "amdgpu-stability-patch";
        url = "https://github.com/torvalds/linux/compare/ffd294d346d185b70e28b1a28abe367bbfe53c04...SeryogaBrigada:linux:4c55a12d64d769f925ef049dd6a92166f7841453.diff";
        hash = "sha256-q/gWUPmKHFBHp7V15BW4ixfUn1kaeJhgDs0okeOGG9c=";
    };
in
{
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
    };

    networking.useDHCP = lib.mkDefault true;
    hardware = {
        graphics = {
            enable = true;
            enable32Bit = true;
        };
    };

    nixpkgs.hostPlatform = {
        system = machine.system;
    };

    boot = {
        loader.limine = {
            enable = true;
        };

        kernelPackages = pkgs.linuxPackages_latest;
        kernelModules = [ "kvm-amd" ];
        extraModulePackages = [
            (userPackages.amdgpu-kernel-module.overrideAttrs (_: {
                patches = [
                    amdgpu-stability-patch
                ];
            }))
        ];
        supportedFilesystems = [ "btrfs" ];

        initrd = {
            compressorArgs = ["-22" "-T0" "--long" "--ultra"];
            availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usbhid" ];
            kernelModules = [ "amdgpu"  ];
            luks.devices."nixos_root".device = "/dev/disk/by-uuid/${machine.partitions.main-luks-id}";
        };
    };

    hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    nix.settings.system-features = [ "gccarch-znver4" ];
}
