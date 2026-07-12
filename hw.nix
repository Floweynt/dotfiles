{ machine, lib, ... }:
let
  required = [
    "/"
    "/nix"
    "/var/log"
    "/persist"
    "/btrfs_root"
    "/boot"
  ];
in
{
  assertions = map (mp: {
    assertion = builtins.hasAttr mp machine.mounts;
    message = "darling-erasure: machine.mounts must define \"${mp}\"";
  }) required;

  fileSystems = machine.mounts;

  boot = {
    initrd = {
      compressorArgs = [
        "-22"
        "-T0"
        "--long"
        "--ultra"
      ];
      luks.devices.${machine.luksDeviceName}.device = "/dev/disk/by-uuid/${machine.luksUuid}";
    };
    supportedFilesystems = [ "btrfs" ];
    loader.limine.enable = true;
  };

  nixpkgs.hostPlatform.system = machine.system;
  nix.settings.system-features = [ "gccarch-${machine.arch}" ];
  networking = {
    hostName = machine.hostname;
    useDHCP = lib.mkDefault true;
  };
}
