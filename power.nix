{
  pkgs,
  ...
}:
{
  powerManagement = {
    enable = true;
    powertop.enable = true;
  };
  services = {
    upower.enable = true;
    power-profiles-daemon.enable = true;
  };
  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="${pkgs.power-profiles-daemon}/bin/powerprofilesctl set low-power"
    SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced"
    SUBSYSTEM=="power_supply", ATTR{online}=="0", RUN+="${pkgs.brightnessctl}/bin/brightnessctl set 70%%"
    SUBSYSTEM=="power_supply", ATTR{online}=="1", RUN+="${pkgs.brightnessctl}/bin/brightnessctl set 100%%"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{bInterfaceClass}=="03", TEST=="power/control", ATTR{power/control}="on"
  '';

  systemd.services.powertop.serviceConfig.ExecStartPost =
    pkgs.writeShellScript "usb-hid-no-autosuspend" ''
      for iface in /sys/bus/usb/devices/*:*/; do
          class=$(cat "$iface/bInterfaceClass" 2>/dev/null)
          if [ "$class" = "03" ]; then
              echo on > "$iface/power/control" 2>/dev/null
              dev="''${iface%:*}"
              echo on > "$dev/power/control" 2>/dev/null
          fi
      done
    '';
}
