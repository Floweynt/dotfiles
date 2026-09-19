mkInstance:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.minecraft;
in
{
  options.programs.minecraft = {
    enable = lib.mkEnableOption "declarative vanilla Minecraft instances";

    defaultMemory = lib.mkOption {
      type = lib.types.str;
      default = "4G";
      example = "6G";
      description = "Default JVM heap size (-Xmx/-Xms) for installed Minecraft instances.";
    };

    account = lib.mkOption {
      type = lib.types.str;
      default = "default";
      description = "Account identifier used for Microsoft authentication at launch.";
    };

    versions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "1.21.4" ];
      description = "Vanilla versions to install, each as a `minecraft-<version>` command.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = map (
      v:
      mkInstance pkgs {
        version = v;
        memory = cfg.defaultMemory;
        inherit (cfg) account;
      }
    ) cfg.versions;
  };
}
