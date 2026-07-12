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
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="32ac", ATTRS{idProduct}=="0012", ATTR{power/control}="on"
    ACTION=="bind", SUBSYSTEM=="usb", ATTRS{idVendor}=="32ac", ATTRS{idProduct}=="0012", ATTR{power/control}="on"
  '';

  # powertop --auto-tune runs after udev enumeration and re-enables autosuspend on all USB
  # devices, including the keyboard. This service runs after powertop to undo that.
  systemd.services.framework-keyboard-no-autosuspend = {
    description = "Disable USB autosuspend for Framework Laptop 16 Keyboard (32ac:0012)";
    wantedBy = [ "multi-user.target" ];
    after = [ "powertop.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.writeShellScript "framework-keyboard-power" ''
        for dev in /sys/bus/usb/devices/*/; do
            vendor=$(cat "$dev/idVendor" 2>/dev/null)
            product=$(cat "$dev/idProduct" 2>/dev/null)
            if [ "$vendor" = "32ac" ] && [ "$product" = "0012" ]; then
                echo on > "$dev/power/control"
            fi
        done
      ''}";
    };
  };
}
