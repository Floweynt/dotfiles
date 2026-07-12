{
  pkgs,
  lib,
  user,
  userPackages,
  ...
}:
let
  script = pkgs.writeShellScript "proxy-service" ''
    ${pkgs.iproute2}/bin/ip route add local default dev lo table 100 2>/dev/null || true
    ${pkgs.iproute2}/bin/ip rule add fwmark 0x01 lookup 100 2>/dev/null || true
    exec ${userPackages.proxy}/bin/proxy
  '';
in
{
  systemd.services.proxy = {
    description = "SSH Tunnel Proxy";
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${script}";
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "3s";
      Environment = "PATH=${
        lib.makeBinPath [
          pkgs.iproute2
          pkgs.openssh
        ]
      }:/run/current-system/sw/bin";
    };
  };
}
