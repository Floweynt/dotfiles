let
  mainDev = "/dev/disk/by-uuid/eda4f358-30ce-4885-9bfb-3f073c524e01";
  btrfsOpts = [
    "noatime"
    "nodiratime"
    "discard"
    "compress=zstd"
  ];
in
{
  machine = {
    hostname = "nix-fw16";
    system = "x86_64-linux";
    arch = "znver4";
    luksDeviceName = "nixos_root";
    luksUuid = "86de28f0-a81e-4fad-abc1-76c8d2336b52";
    drmDevice = "/dev/dri/card2";
    mounts = {
      "/" = {
        device = mainDev;
        fsType = "btrfs";
        options = btrfsOpts ++ [ "subvol=@root" ];
      };
      "/nix" = {
        device = mainDev;
        fsType = "btrfs";
        options = btrfsOpts ++ [ "subvol=@nix" ];
      };
      "/var/log" = {
        device = mainDev;
        fsType = "btrfs";
        options = btrfsOpts ++ [ "subvol=@logs" ];
        neededForBoot = true;
      };
      "/persist" = {
        device = mainDev;
        fsType = "btrfs";
        options = btrfsOpts ++ [ "subvol=@persist" ];
      };
      "/btrfs_root" = {
        device = mainDev;
        fsType = "btrfs";
        options = btrfsOpts ++ [ "ro" ];
      };
      "/boot" = {
        device = "/dev/disk/by-uuid/98B1-85E1";
        fsType = "vfat";
        options = [
          "fmask=0022"
          "dmask=0022"
        ];
      };
    };
  };

  nixosModule =
    {
      pkgs,
      lib,
      config,
      nixos-hardware,
      ...
    }:
    {
      imports = [
        (import "${nixos-hardware}/framework/16-inch/7040-amd")
        ../extern/framework-lid-workaround.nix
      ];
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
        enableRedistributableFirmware = true;
        cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      };
      boot = {
        kernelModules = [ "kvm-amd" ];
        kernelPackages = pkgs.linuxPackages_6_18;
        initrd.availableKernelModules = [
          "nvme"
          "xhci_pci"
          "thunderbolt"
          "usbhid"
        ];
        initrd.kernelModules = [ "amdgpu" ];
      };
    };
}
